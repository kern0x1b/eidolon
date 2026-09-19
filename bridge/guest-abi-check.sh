#!/bin/bash
# guest-abi-check.sh: гостевая сборка модуля (arm64, с библиотечной эволюцией) против интерфейса Apple.
# Проверяет три вещи: модуль собирается, приложение Apple-сборки линкуется с ним без неразрешённых
# символов SwiftUI, и ни один класс образа не получил нулевую фиксированную раскладку (иначе на iOS 6
# класс реализуется по пустой раскладке, потому что _objc_realizeClassFromSwift там нет).
set -e
cd "$(dirname "$0")"
source ../pkg-env.sh; O=arm64; mkdir -p $O
COMMON="-target arm64-apple-ios14.0 -sdk $SDK -O -wmo -parse-as-library -runtime-compatibility-version none -suppress-warnings"

/usr/bin/swiftc $COMMON -module-name SwiftUI -D REV_SYSTEM_COMBINE -D REV_NO_FIELD_REFLECTION \
  -enable-library-evolution -no-verify-emitted-module-interface \
  -emit-module -emit-module-path $O/SwiftUI.swiftmodule -c ../eidolon/Sources/SwiftUI/*.swift -o $O/SwiftUI.o
echo "guest module built"

/usr/bin/swiftc $COMMON -F fw -module-name demo -c app.swift -o $O/app.o
echo "sample app built against Apple's interface"

/usr/bin/swiftc -target arm64-apple-ios14.0 -sdk $SDK -o $O/demo $O/app.o $O/SwiftUI.o \
  -framework UIKit -framework Foundation -framework Combine -Xlinker -no_adhoc_codesign 2>&1 | grep -v "^ld: warning" || true
[ -f $O/demo ] || { echo "FAIL: приложение не слинковалось с нашей реализацией"; exit 1; }

left=$(nm -u $O/demo | grep -c SwiftUI || true)
[ "$left" = 0 ] || { echo "FAIL: осталось $left неразрешённых символов SwiftUI"; nm -u $O/demo | grep SwiftUI | head; exit 1; }
echo "link: 0 unresolved SwiftUI symbols"

need=$(nm -u app.o 2>/dev/null | grep -c "SwiftUI" || nm -u $O/app.o | grep -c "SwiftUI")
echo "app imports $need SwiftUI symbols, all satisfied"

zero=$(otool -ov $O/demo | grep -c "instanceSize 0$" || true)
[ "$zero" = 0 ] || { echo "FAIL: $zero классов с нулевой фиксированной раскладкой (на iOS 6 это падение при реализации класса)"; exit 1; }
total=$(otool -ov $O/demo | grep -c "instanceSize" || true)
echo "fixed layout: $total classes, none with instanceSize 0"
echo "guest ABI check passed"
