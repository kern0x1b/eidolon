# Eidolon

Своя реализация SwiftUI для iOS 6 armv7 поверх UIKit шестой системы. Имя — εἴδωλον, «образ, облик»:
призрачный двойник у Гомера; в семье Charon, Shade и Revenant (Revenant — это движок WebKit, не этот проект).

**Это не SwiftUI Apple.** Ни строки кода Apple здесь нет и не будет: у настоящего SwiftUI нет исходников,
он существует только как бинарник для arm64, и на iOS 6 он не переносится (разбор и цифры — в `../docs/research.md`).

**Модуль называется `SwiftUI`, а не Eidolon, и это обязательно.** От имени модуля зависят манглы всех символов,
которые приложение берёт у SwiftUI: с другим именем приложение не собралось бы без правки `import SwiftUI`
и не связалось бы как гостевое для рекомпилятора. Eidolon — имя проекта, каталога, целей и документов.

Совместимость двух видов:
- **по исходникам** — приложение на обычном синтаксисе SwiftUI компилируется против этого модуля без правок текста;
- **по поверхности символов** для гостевой сборки рекомпилятора — модуль, собранный с библиотечной эволюцией,
  удовлетворяет все 64 символа SwiftUI, которые берёт подопытное приложение Apple-сборки (`../bridge/README.md`).
  Раскладки внутренних типов и точки входа графа у нас свои.

## Состояние

Прототип. Достаточно для экрана со списком, навигацией, состоянием и наблюдаемой моделью;
не достаточно для произвольного чужого кода.

### Что поддержано, что игнорируется, чего нет

Счёт ведётся скриптом `coverage.py` по интерфейсу SwiftUI из SDK 16.4 (592 публичных типа, 311 модификаторов `View`).
На сегодня: **504 типов** и **311 модификаторов**, из них **189 действуют**, 0 заглушки (пишут в журнал), 122 объявлены и игнорируются.
Из того, что Apple объявляет доступным на iOS: **491 из 520 типов** и **289 из 289 модификаторов**, из них **188 действуют**, 0 заглушки, 101 игнорируются
(остальное в интерфейсе помечено `@available(iOS, unavailable)` — это macOS, tvOS и watchOS; списки строит `../bridge/ios-surface.py`).

**Что эти числа не говорят.** Счёт выше — по *именам* типов и модификаторов. По декларациям картина строже:
типизированный разбор `swift-api-digester` (`../bridge/api-surface.sh`, колонки отчёта — `../bridge/api-diff.py`)
сравнивает интерфейс Apple SwiftUI для iOS 16.4 с нашим модулем по подписи каждой декларации и на 19.09 находит
**1402 декларации Apple, которых у нас нет вовсе, и 321, которые есть, но с другой подписью** (вызов, который
компилируется у нас благодаря значениям параметров по умолчанию, отсутствующим не считается). Заметная часть первых —
то, чему в iOS 6 нечему соответствовать (Widgets, документы, окна, `UIHostingConfiguration`, роторы доступности);
остальное — работа, которая ещё не сделана: перегрузки вроде `Stepper`, `TextField` с `prompt:`/`axis:`, 48 ключей
`EnvironmentValues`, 28 случаев `BlendMode` вместо наших семи, `Table` целиком. Этот список — рабочая очередь;
закрытый перечень «нечему соответствовать» с причинами будет вестись рядом, и сборка будет падать, если
отсутствующее не в нём и не в очереди.

**Действуют** (видны на экране и в тестах):

| Область | Что есть |
|---|---|
| Описание | `View`, `ViewBuilder` (вариадический), `if`/`else`, `TupleView`, `Group`, `AnyView`, `EmptyView`, `ViewModifier`, `ModifiedContent` |
| Состояние | `@State`, `@Binding`, `@ObservedObject`, `@StateObject`, `@EnvironmentObject`, `@Environment` по ключам, `@AppStorage`, `@FocusState`, `@GestureState`, `ObservableObject`/`@Published`; стандартные ключи окружения: `colorScheme`, `locale`, `calendar`, `timeZone`, `isEnabled`, `layoutDirection`, `sizeCategory`, `controlSize`, `horizontalSizeClass`, `displayScale`, `openURL`, `dismiss`, `editMode`, `font`, `multilineTextAlignment`, `redactionReasons`, `isSearching` |
| Представления | `Text` (шрифт, цвет, начертание, подчёркивание, зачёркивание, регистр, склейка `+`, даты), `Button`, `Toggle`, `TextField`, `SecureField`, `TextEditor`, `Slider`, `Stepper`, `ProgressView` (с подписью и текущим значением, по интервалу времени с `DefaultDateProgressLabel`), `Gauge`, `Picker` (сегменты), `DatePicker`, `MultiDatePicker` (сетка месяца на нашем `Grid`), `Menu`, `Link`, `ShareLink` (`UIActivityViewController`), `Label`, `GroupBox`, `ControlGroup`, `DisclosureGroup`, `Image` (с `resizable`, `aspectRatio`), `AsyncImage` (`NSURLConnection`), `Color`, `Divider`, `Spacer`, `ForEach` с идентичностью и по привязке (`ForEach($items)`, `List($items)`, `editActions:` удаляют и двигают через привязку), `TimelineView`, `Canvas` с настоящим `GraphicsContext` (градиентные заливки, текст и картинки через `resolve`, символы, `clip(options: .inverse)`, `clipToLayer`, `blendMode`, фильтр тени; размытие и цветовые фильтры CoreGraphics iOS 6 не умеет — пишут в журнал) |
| Фигуры | `Shape`, `Path`, `Rectangle`, `RoundedRectangle`, `Circle`, `Ellipse`, `Capsule`, `AnyShape`, `fill`/`stroke`/`strokeBorder` со `ShapeStyle` и полным `StrokeStyle` (пунктир, фаза, концы, стыки), заливка и обводка фигур градиентом, преобразования (`offset`, `scale`, `rotation`, `transform`), `inset(by:)`, `Gradient`, `LinearGradient`, `RadialGradient`, `EllipticalGradient`, `AngularGradient` (секторами — конического градиента в iOS 6 нет), `AnyGradient` и `Color.gradient`, `AnyShapeStyle`, иерархические стили `.primary`…`.quaternary`, `.selection`, `.tint`, `Material` (полупрозрачная заливка без размытия, пишет в журнал), `ShadowStyle` (`.drop` — тень слоя; `.inner` пишет в журнал) |
| Раскладка | `VStack`, `HStack`, `ZStack`, `HStackLayout`, `VStackLayout`, `ZStackLayout` (и через `AnyLayout`), `LazyVStack`, `LazyHStack`, `LazyVGrid`, `LazyHGrid`, `Grid` и `GridRow` с выравниванием колонок по всем строкам, строками на всю ширину, `gridCellColumns`, `gridCellAnchor`, `gridCellUnsizedAxes`, `gridColumnAlignment`, `ScrollView`, `ScrollViewReader` со `scrollTo(id, anchor:)` в `ScrollView` и в `List`, `GeometryReader` с `frame(in:)` в `.local`, `.global` и именованном пространстве (`coordinateSpace(name:)`), `ViewThatFits`, `padding` по сторонам, полный `frame`, `fixedSize`, `layoutPriority`, `aspectRatio`, `alignmentGuide` и свои выравнивания через `AlignmentID`, `baselineOffset`, протокол `Layout` со своими раскладками (`ProposedViewSize`, `LayoutSubviews`, `AnyLayout`, `LayoutValueKey` и `layoutValue`) |
| Списки | `List` с выбором (`selection:` одной строки и множеством), `Table` (на iPhone — как у Apple: одна первая колонка списком; `TableColumn`, строители колонок и строк, `tableStyle`), `Form`, `Section` с заголовком и футером (`headerProminence(.increased)` — свой крупный заголовок секции), `listItemTint`, удаление и перемещение строк (`remove(atOffsets:)`, `move(fromOffsets:toOffset:)`), `deleteDisabled`, `moveDisabled`, `swipeActions` (одно действие — кнопка свайпа с его названием; несколько — кнопка «More» и `UIActionSheet` со всеми), `Button(role:)`, `EditButton`, `refreshable`, `searchable` (в списке — в шапке таблицы, у прочего содержимого — строка поиска над ним), `searchScopes` (кнопки области `UISearchBar`), `searchSuggestions` и `searchCompletion` (пока поле поиска активно, подсказки — своим списком поверх таблицы или вместо содержимого; строка с `searchCompletion` по нажатию подставляет текст), `isSearching` в окружении, `buttonStyle` с `PrimitiveButtonStyle` и `Button(configuration)`, фон и отступы строки, кэш ячеек |
| Навигация | `NavigationView`, `NavigationLink` (касанием вне списка тоже, `isActive`, `tag`/`selection`), `NavigationSplitView` (на iPhone — стек: выбор строки в `List(selection:)` открывает следующую колонку, возврат снимает выбор), `OutlineGroup` и `List(_:children:)`, `navigationTitle`, `navigationBarItems`, `toolbar`, `TabView` с `tabItem` и `badge`, `TabView` со стилем `.page` (листание `UIScrollView` и точки `UIPageControl`, `indexViewStyle`), `navigationBarHidden` |
| Система | `onOpenURL` (делегат приложения передаёт URL обработчикам на экране), `statusBarHidden` и старое `statusBar(hidden:)` (`setStatusBarHidden`), `toolbarColorScheme` для панели навигации (`UIBarStyleBlack`; у `UITabBar` iOS 6 стиля нет — пишет в журнал), `submitLabel` (`returnKeyType`; `.continue` пишет в журнал — такой клавиши в iOS 6 нет), `badge` (у вкладки — `badgeValue`, у строки списка — плашка справа), `scrollContentBackground(.hidden)`, `redacted`/`unredacted`/`privacySensitive` (заглушки-плашки вместо текста и картинок), `help` (как подсказка доступности, как у Apple на iOS), старое написание `accessibility(label:hint:value:hidden:identifier:addTraits:removeTraits:)` |
| Время | `TimelineView` по расписаниям Apple (`periodic`, `everyMinute`, `animation` с `minimumInterval` и `paused`, `explicit`) и свои `TimelineSchedule` через `entries(from:mode:)` |
| Модальность | `.sheet` (в том числе `sheet(item:)`), `.fullScreenCover`, `.alert` (родной `UIAlertView`), `.actionSheet`, `.confirmationDialog`, `contextMenu`, `presentationMode` |
| Оформление | фон и накладка стилем (`.background(.ultraThinMaterial)`, `.background(.blue, in: Capsule())`, `.background(in:)` с `backgroundStyle`), `foregroundStyle` со `ShapeStyle`, `containerShape` для `ContainerRelativeShape`, `contentTransition` (смена текста наплывом `CATransition`), `projectionEffect` (`CATransform3D`), `compositingGroup` (растеризация слоя — так в iOS 6 получается групповая прозрачность), `buttonBorderShape` для `bordered`/`borderedProminent`, `opacity`, `cornerRadius`, `border`, `shadow`, `clipped`, `clipShape`, `offset`, `rotationEffect`, `scaleEffect`, `overlay`, `background` видом, `hidden`, `zIndex`, `drawingGroup`, `redacted` |
| Жесты | Движок с типизированными событиями: `TapGesture`, `SpatialTapGesture`, `LongPressGesture` (нажатие с момента касания, а не через `minimumDuration`), `DragGesture` (с `minimumDistance` и `coordinateSpace`), `MagnificationGesture`, `RotationGesture`; `onChanged`, `onEnded`, `map`, `updating` с `@GestureState` (значение сбрасывается, когда жест кончился или отменён), `simultaneously`, `sequenced` (второй жест ждёт первого), `exclusively` (второй ждёт, пока не откажет первый), `AnyGesture`, жесты, собранные через `body`; `gesture`, `simultaneousGesture`, `highPriorityGesture` с `including:`; `onTapGesture`, `onLongPressGesture` с `onPressingChanged`; `contentShape` (форма, в которой жест принимает касание) |
| Анимация | `Animation`, `withAnimation`, `.animation` поверх `UIView.animate`, `repeatForever`, `repeatCount` (с `autoreverses`), `transition`, `matchedGeometryEffect` с `@Namespace`; **данные `Animatable` интерполируются кадр за кадром** у своих `Shape` (`animatableData`), `GeometryEffect`, `ViewModifier & Animatable` и `Layout`; у встроенных — `trim`, углы `RoundedRectangle`, `offset`, `scale`, `rotation` фигур |
| Геометрия | `Path` (`forEach`, `addLines`, `addRects`, `addRelativeArc`, `strokedPath`, `trimmedPath`), `Shape.trim`, `Shape.size`, `Shape.sizeThatFits` (круг берёт меньшую сторону), `GeometryEffect` (переход слоя по `ProjectionTransform`, начало координат в левом верхнем углу, как у Apple), `ProjectionTransform` (`concatenating`, `inverted`, `isAffine`) |
| Анимация | `Animation`, `withAnimation`, `.animation` поверх `UIView.animate`, `transition`, `matchedGeometryEffect` с `@Namespace` (новый вид едет из места старого) |
| Core Data | `@FetchRequest` и `SectionedFetchRequest` поверх `NSFetchedResultsController` (перечитывание при сохранении контекста, изменение предиката и сортировки через `$request`), `FetchedResults`, `SectionedFetchResults`, `\.managedObjectContext` |
| Данные и события | `onAppear`, `onDisappear`, `onChange`, `onReceive`, `.id`, `tag`, `PreferenceKey` с `onPreferenceChange`, `transformPreference`, якоря (`Anchor`, `anchorPreference`, `transformAnchorPreference`, `GeometryProxy[anchor]`), `overlayPreferenceValue`/`backgroundPreferenceValue`, `@FocusState` с `.focused`, `Transaction`/`withTransaction`, `EquatableView` |
| Своё | `DynamicProperty` (свои обёртки свойств с вложенными `@State` и `update()`), `PreviewProvider` (собирается, в приложении не исполняется — как у Apple) |
| Мост к UIKit | `UIViewRepresentable`, `UIViewControllerRepresentable` с координатором и контекстом |
| Стили | `ButtonStyle` и `ToggleStyle` с настоящим `makeBody` и живым `isPressed` (готовые `automatic`, `plain`, `bordered`, `borderedProminent`, `switch`, `button`), `TextFieldStyle`, `ListStyle` (plain/grouped/insetGrouped), `PickerStyle` (сегменты, колесо `UIPickerView` с `defaultWheelPickerItemHeight`, меню `UIActionSheet`, `.navigationLink` — строка с текущим значением, открывающая список выбора, `.inline` — варианты строками с галочкой), `LabelStyle`, `ProgressViewStyle`, `MenuStyle`, `DisclosureGroupStyle`, `GroupBoxStyle`, `LabeledContentStyle`, `ControlGroupStyle` (в том числе `.menu`), `GaugeStyle` (линейный и круговой `accessoryCircular`), `FormStyle` — все со своими `makeBody` и конфигурацией, `navigationViewStyle` (на iPhone любой стиль — стек, как и у Apple), `datePickerStyle(.wheel)` |
| Локализация | `LocalizedStringKey` ищет строку в бандле (`NSLocalizedString`), интерполяция подставляется как есть |
| Доступность | `accessibilityAdjustableAction` и `accessibilityScrollAction` (`accessibilityIncrement`/`Decrement`/`accessibilityScroll` у своего вида-обёртки), `accessibilityActivationPoint`, `accessibilityLabel`, `Value`, `Hint`, `Identifier`, `AddTraits`, `RemoveTraits`, `Element`, `Hidden`, `Heading` через `UIAccessibility` |
| Приложение | `App`, `Scene`, `WindowGroup`, `@main`, `UIHostingController` (с `sizingOptions`), живой `scenePhase` (`.active`/`.inactive`/`.background` от делегата приложения), `SceneStorage`, `Commands` и `.commands` (собираются; меню и клавиатурных команд в iOS 6 нет — пишет в журнал), `ToolbarContent` с `ToolbarContentBuilder` |

**Объявлены и игнорируются** — то, чему на iOS 6 нечему соответствовать. При первом применении каждый
печатает одну строку в журнал (`[SwiftUI] blur ignored on iOS 6: iOS 6 has no live blur`), список за прогон
доступен в `_Unsupported.used` и печатается тестами:

`blendMode`, `blur`, `brightness`, `colorInvert`, `colorMultiply`, `contrast`,
`defersSystemGestures`, `dynamicTypeSize`, `edgesIgnoringSafeArea`, `grayscale`, `ignoresSafeArea`, `interactiveDismissDisabled`, `keyboardShortcut`, `navigationBarTitleDisplayMode`,
`persistentSystemOverlays`, `preferredColorScheme`, `saturation`, `symbolRenderingMode`, `textSelection`, `accessibilityShowsLargeContentViewer`,
`accessibilityIgnoresInvertColors`, `accessibilityRespondsToUserInteraction`,
`accessibilityInputLabels`, `listRowSeparator`, `widgetAccentable`, `onDrag`, `onDrop`,
`Image(systemName:)` (имя ищется в бандле, символов у системы нет), `textContentType`, `fontWidth`, `listSectionSeparator`, `swipeActions(edge: .leading)` (строка `UITableView` в iOS 6 свайпается только справа), `datePickerStyle(.compact)` и `datePickerStyle(.graphical)` (у `UIDatePicker` в iOS 6 есть только колесо), а также то, чего в шестой системе нет как явления — перетаскивание, буфер обмена рабочего стола,
фокус-движок, документы, детенты модальных экранов, указатель, SF Symbols, watchOS и macOS:
`accessibilityActions`, `accessibilityAction` (свои действия доступности появились в iOS 8; VoiceOver в iOS 6 делает двойное касание по самому виду), `accessibilityCustomContent`, `accessibilityLabeledPair`, `accessibilityLinkedGroup`, `accessibilityTextContentType`, `speechAdjustedPitch`, `speechAlwaysIncludesPunctuation`, `speechAnnouncementsQueued`, `speechSpellsOutCharacters`, `focusable`, `focusSection`, `defaultFocus`, `prefersDefaultFocus`, `draggable`, `dropDestination`, `copyable`, `cuttable`, `itemProvider`, `onCopyCommand`, `onCutCommand`, `onPasteCommand`, `onDeleteCommand`, `onMoveCommand`, `onExitCommand`, `onPlayPauseCommand`, `fileExporter`, `fileImporter`, `fileMover`, `renameAction`, `findNavigator`, `findDisabled`, `replaceDisabled`, `presentationDetents`, `presentationDragIndicator`, `presentationCornerRadius`, `presentationBackground`, `presentationCompactAdaptation`, `toolbarRole`, `menuIndicator`, `menuOrder`, `menuActionDismissBehavior`, `hueRotation`, `luminanceToAlpha`, `onHover`, `onContinuousHover`, `hoverEffect`, `symbolVariant`, `flipsForRightToLeftLayoutDirection`, `interactionActivityTrackingTag`, `handlesExternalEvents`, `userActivity`, `onContinueUserActivity`, `navigationDocument`, `previewDevice`, `previewLayout`, `previewDisplayName`, `previewInterfaceOrientation`, `margins`, `submitScope`, `digitalCrownRotation`, `horizontalRadioGroupLayout`, `touchBar`, `onLongTouchGesture`, `accessibilityChartDescriptor`, `accessibilityQuickAction`, `accessibilityRotor`, `accessibilityRotorEntry`, `digitalCrownAccessory`, `exportableToServices`, `exportsItemProviders`, `importableFromServices`, `importsItemProviders`, `focusScope`, `focusedValue`, `focusedObject`, `focusedSceneValue`, `focusedSceneObject`, `listRowPlatterColor`, `listRowSeparatorTint`, `listSectionSeparatorTint`, `menuButtonStyle`, `onCommand`, `pageCommand`, `pasteDestination`, `presentationBackgroundInteraction`, `presentationContentInteraction`, `presentedWindowStyle`, `presentedWindowToolbarStyle`, `previewContext`, `toolbarTitleMenu`, `touchBarCustomizationLabel`, `touchBarItemPresence`, `touchBarItemPrincipal`.

Список закрытый: попасть в него может только то, чему на iOS 6 действительно нечему соответствовать,
и только вместе со строкой причины. Проверяется сборкой (`coverage.py --check`): если в исходниках появился
игнорируемый API без описания в этом разделе или счёт упал ниже `coverage-baseline.json`, сборка падает.

**Сделаны частично** — работает основной случай, остаток пишет в журнал `unimplemented` и попадает в отчёт прогона:
`navigationViewStyle(.columns)`, `NavigationSplitView`, `navigationSplitViewStyle`, `navigationSplitViewColumnWidth` и колонки `Table` на iPad (колонок `UISplitViewController` пока нет, показывается стек),
`matchedGeometryEffect(isSource: false)` (не-источник не подстраивается под источник).

**Упрощены** — работают, но с расхождением, которого iOS 6 не позволяет избежать; каждое пишет строку в журнал и
отчёт прогона при первом использовании: `Animation.spring` (и `interactiveSpring`, `interpolatingSpring`: у `UIView` нет пружинной анимации — кривая
ease-out той же длительности, затухание не моделируется), `Animation.timingCurve` (в iOS 6 четыре кривые времени и
нет кубической Безье — берётся ближайшая из них), `ShadowStyle.inner` (внутренних теней в CoreAnimation нет — не рисуется),
`Text.LineStyle.Pattern` (только сплошные подчёркивание и зачёркивание), `Font.leading` (вариантов интерлиньяжа у
`UIFont` нет — используйте `lineSpacing`), `Font.Design.rounded` (скруглённого системного шрифта нет — обычный),
`foregroundStyle(gradient)` у текста (текст одного цвета — первый цвет градиента), `submitLabel(.continue)`
(клавиши Continue нет — показывается Return), `scrollDismissesKeyboard` (на iOS 6 прокрутка клавиатуру не прячет;
с iOS 7 работает через `keyboardDismissMode`), `toolbarColorScheme(for: .tabBar)` (у `UITabBar` нет стиля панели),
`Button(role: .destructive)` в `alert` (у `UIAlertView` iOS 6 нет стиля разрушающей кнопки — она выглядит как остальные; в `confirmationDialog` она красная), `ShareLink(subject:)` (окно «Поделиться» iOS 6 не принимает тему), `commands` у сцены (в iOS 6 нет ни строки меню,
ни клавиатурных команд), `gesture(including:)` без `.subviews` (распознаватели iOS 6 нельзя выключить для всей
иерархии — жесты подвидов остаются включёнными; без `.gesture` жест просто не подключается). Приоритет жестов
устроен иначе, чем в SwiftUI: распознаватели предка и потомка срабатывают одновременно, а не «потомок побеждает»;
`highPriorityGesture` заставляет распознаватели потомков ждать распознавателя предка, `simultaneousGesture` не
отличается от `gesture`. `Layout.spacing` не читается родительским стеком: расстояния между видами задаёт
сам стек. Анимация `Animatable`-данных идёт по времени, кривой и повторам `Animation`; пружина заменена кривой
ease-out (см. выше). `coverage.py --check` требует, чтобы каждая такая запись в коде была названа здесь.

**Заглушек нет.** Последние четыре — доступность — сделаны на средствах iOS 6: `accessibilityRepresentation`
(метка, значение и черты элемента берутся из представления — кнопки, переключателя, ползунка, степпера, текста),
`accessibilityChildren` (вид становится `UIAccessibilityContainer`, дети раскладываются в его рамке и отдаются как
`UIAccessibilityElement`), `accessibilitySortPriority` (корневой вид хоста — контейнер, который при заданных
приоритетах упорядочивает элементы по приоритету, затем по положению на экране), `accessibilityFocused` (привязка
переводит фокус VoiceOver уведомлением `UIAccessibilityLayoutChangedNotification` с элементом, а фокус VoiceOver
пишет привязку через `accessibilityElementDidBecomeFocused`/`DidLoseFocus`). Имя каждой будущей заглушки счётчик
читает из вызова; вызов, имени которого он прочесть не может, валит сборку — так заглушка не спрячется от счёта.

**Нет вовсе** — таких API в модуле нет, приложение с ними не соберётся: лучше ошибка компиляции, чем тихо
неправильный экран. Это `@Observable` и макросы Observation (нужен модуль Observation), `NavigationStack(path:)`
(`NavigationStack` есть как стек без пути), и типы из списка `coverage.py --missing`, не попавшие ни в одну из групп выше.

## Две сборки модуля

- **Нативная** (приложение компилируется из исходников под armv7 iOS 6) — без библиотечной эволюции.
- **Гостевая** (для конвейера рекомпилятора: модуль собирается под arm64 и переводится вместе с приложением) —
  с `-enable-library-evolution`, иначе компилятор не выпускает method descriptors протоколов, которых
  требует приложение, собранное против интерфейса Apple. Проверяется скриптом `../bridge/guest-abi-check.sh`:
  он линкует подопытное приложение Apple-сборки с нашим модулем (сейчас 64 из 64 символов удовлетворены)
  и следит, чтобы ни один класс образа не получил нулевую фиксированную раскладку — на iOS 6 такой класс
  падает при реализации, потому что `_objc_realizeClassFromSwift` там нет.

Из этого следуют требования к коду: модуль называется `SwiftUI`, имена и метки аргументов совпадают
с Apple дословно, порядок требований протоколов — слот в слот (таблица в `../bridge/README.md`),
публичные классы хранят только свойства статически известного размера.

## Устройство

- `Sources/SwiftUI/Core.swift` — протокол `View`, построитель, прозрачные контейнеры.
- `Sources/SwiftUI/Graph.swift` — дерево узлов, согласование, транзакции обновления, вписывание динамических свойств по смещениям полей из метаданных Swift.
- `Sources/SwiftUI/State.swift` — обёртки свойств и их хранилища в узлах.
- `Sources/SwiftUI/Layout.swift` — модель раскладки, стеки, `Spacer`, `padding`, `frame`.
- `Sources/SwiftUI/Views.swift` — примитивные представления поверх контролов UIKit.
- `Sources/SwiftUI/Modifiers.swift` — модификаторы как узлы и как изменение окружения.
- `Sources/SwiftUI/List.swift`, `Navigation.swift` — `UITableView` и `UINavigationController`.
- `Sources/SwiftUI/Presentation.swift` — лист и предупреждение, `Sources/SwiftUI/Environment.swift` — ключи окружения.
- `Sources/SwiftUI/Hosting.swift` — контроллер-хост, `Sources/SwiftUI/App.swift` — запуск приложения.
- `Sources/SwiftUI/Probe.swift` — служебный доступ для тестов (дерево, размеры строк, число вычислений `body`).

## Сборка и проверка

```
./build.sh                       # модуль SwiftUI, EidolonDemo.app, EidolonTests, EidolonProbe (armv7, iOS 6)
../run-emu.sh t1 out/EidolonDemo.app EidolonTests          # модульные тесты движка в iLEmu
../snapshots.sh [--accept]                          # снимочные тесты: деревья сценариев против Snapshots/reference
../run-app.sh app1 out/EidolonDemo.app 560 ../scratch/ctl7.txt   # демо в эмуляторе со сценарием касаний
```

Сборка идёт против установки пакета `charon@swift-runtime` 6.4.0 (charon main 70c716c, метка сборки
`charon_swift_runtime_9c2013b4…`) в приватном `../xmake-global`; пути и флаги — в `../pkg-env.sh`.
Все модули и dylib — из одной установки: стандартная библиотека, конкурентность, оверлеи Foundation, UIKit,
QuartzCore, CoreGraphics, Dispatch, ObjectiveC, CoreFoundation и CoreData. Цель — `armv7-apple-ios6.0` с
`-bundled-swift-runtime`, **проверка доступности включена**: любое API новее iOS 6 компилятор называет сам, а не
падение на устройстве (так нашлись и исправлены `CGPathAddRoundedRect`, `component(_:from:)`,
`keyboardDismissMode`, `contentSizeForViewInPopover`; `NSItemProvider`/`NSUserActivity` в подписях помечены iOS 8).
Combine — пакет `charon@opencombine` 2023.10.11 (charon main c7a6139) из той же установки, собранный против того же
рантайма: без издателей `URLSession` (iOS 7), допуск таймера — за `#available`; `../rtpkg` требует его, `pkg-env.sh`
находит установку по хэшу рантайма. Свой прогон тестов OpenCombine — `../combine/build.sh pkg` (1448 из 1453).

## Замеры

- Модульные тесты движка: 260 проверок (раскладка, выравнивания, сетка, состояние, наблюдаемые объекты, окружение,
  списки, их правка и выбор, секции, `ZStack`, `ScrollView`, идентичность в `ForEach`, стили, жесты и их формы,
  пространства координат, переходы, `matchedGeometryEffect`, предпочтения и якоря, градиенты по пикселям,
  `Canvas`, `@FetchRequest` с живым обновлением из Core Data, доступность), iLEmu iPhone4,1 iOS 6.1.3 и живой
  iPad 2 (iOS 6.1.3) — все проходят.
- Снимочные сценарии в приложении (iPod4,1 iOS 6.0): 16 деревьев, сверяются посимвольно с эталонами в
  `Snapshots/reference`; эталон нового сценария записывается только после ручной проверки дерева.
- Производительность (безоконный пробник `EidolonProbe`, живое железо iOS 6.1.3; `../device-run/`): простой экран —
  полное обновление 1,6 мс на iPad 2 и 2,1 мс на iPhone 4S, первичная сборка и раскладка 6,5 мс. Глубокий экран —
  шесть строк вложенных стеков глубины d — до кэша размеров рос в 7–8 раз на уровень (d=3: 1174 мс на обновление,
  d=6 не дождались за 15 минут), с кэшем растёт линейно: d=1 — 14 мс, d=3 — 56 мс, d=6 — 139 мс (iPad 2). На iPhone 4S (те же сборка и сценарий, финальная версия): d=1 — 19 мс, d=3 — 78 мс, d=5 — 139 мс; обновление одной строки из шести — 4,9 / 15 / 25 мс. Кэш:
  у каждого узла раскладки до 32 ответов «предложение → размер»; сбрасывается при обновлении узла, у его
  вложенных узлов раскладки и у всех предков. Синхронизация подвидов (`mountContents()`) и применение кадра
  (`place()`) дополнительно пропускаются для узла, чей кадр не изменился и который не был помечен грязным —
  когда меняется только одна строка из шести, обновление на iPad 2 падает: d=1 — 3,4 мс, d=3 — 10 мс, d=5 — 18 мс.
  Текст (внутри приложения, `perf.sh`; вне приложения на устройстве нет шрифтового сервера, процесс падает на
  первом `Text`) идёт немного дороже цвета на глубоких экранах из-за измерения строк, но растёт так же линейно.

## Ограничения окружения

- Приложение с интерфейсом запускается только установленным в `/Applications`; из временной папки
  iOS 6 не отдаёт ему дисплей (`GSRegisterPurpleNamedPort`, ошибка 1100). Поэтому на устройстве гоняется
  только безоконный пробник, а UI проверяется в эмуляторе.
- `UIFont` в процессе без `UIApplication` на iOS 6 падает, поэтому консольные тесты не используют текст.
- iLEmu на 6.1.3 не поднимает SpringBoard, UI-прогоны идут на iPod4,1 6.0.
