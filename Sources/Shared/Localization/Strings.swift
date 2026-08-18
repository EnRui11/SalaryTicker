import Foundation
import SalaryDomain

/// Every user-facing string in the app.
///
/// One entry per string, with all nine translations passed as labelled arguments. The
/// shape is deliberate: the compiler enforces completeness, so adding a language to
/// `AppLanguage` breaks `t` until every string is translated and a half-localized build
/// cannot ship. No bundle, no `.strings` files, no build phase.
public struct Strings: Sendable {
    public let language: AppLanguage

    public init(_ language: AppLanguage) { self.language = language }

    private func t(
        en: String, zh: String, ja: String, ko: String, es: String,
        fr: String, de: String, pt: String, ms: String
    ) -> String {
        switch language {
        case .english: en
        case .chinese: zh
        case .japanese: ja
        case .korean: ko
        case .spanish: es
        case .french: fr
        case .german: de
        case .portuguese: pt
        case .malay: ms
        }
    }

    // MARK: Durations

    public func hoursMinutes(_ h: Int, _ m: Int) -> String {
        t(en: "\(h)h \(m)m", zh: "\(h) 小时 \(m) 分", ja: "\(h)時間\(m)分", ko: "\(h)시간 \(m)분",
          es: "\(h) h \(m) min", fr: "\(h) h \(m) min", de: "\(h) Std. \(m) Min.",
          pt: "\(h) h \(m) min", ms: "\(h) jam \(m) min")
    }

    public func minutesSeconds(_ m: Int, _ s: Int) -> String {
        t(en: "\(m)m \(s)s", zh: "\(m) 分 \(s) 秒", ja: "\(m)分\(s)秒", ko: "\(m)분 \(s)초",
          es: "\(m) min \(s) s", fr: "\(m) min \(s) s", de: "\(m) Min. \(s) Sek.",
          pt: "\(m) min \(s) s", ms: "\(m) min \(s) saat")
    }

    public func seconds(_ s: Int) -> String {
        t(en: "\(s)s", zh: "\(s) 秒", ja: "\(s)秒", ko: "\(s)초",
          es: "\(s) s", fr: "\(s) s", de: "\(s) Sek.", pt: "\(s) s", ms: "\(s) saat")
    }

    // MARK: Status

    public var dayOff: String {
        t(en: "Day off", zh: "今天休息", ja: "本日は休み", ko: "오늘은 휴무",
          es: "Día libre", fr: "Jour de repos", de: "Freier Tag", pt: "Dia de folga",
          ms: "Hari cuti")
    }

    public func startsIn(_ d: String) -> String {
        t(en: "Starts in \(d)", zh: "还有 \(d) 上班", ja: "あと\(d)で開始", ko: "\(d) 후 시작",
          es: "Empieza en \(d)", fr: "Commence dans \(d)", de: "Beginnt in \(d)",
          pt: "Começa em \(d)", ms: "Bermula dalam \(d)")
    }

    public func untilClockOff(_ d: String) -> String {
        t(en: "\(d) until clock-off", zh: "距离下班 \(d)", ja: "退勤まで\(d)", ko: "퇴근까지 \(d)",
          es: "\(d) hasta la salida", fr: "\(d) avant la fin", de: "Noch \(d) bis Feierabend",
          pt: "\(d) até a saída", ms: "\(d) lagi sebelum balik")
    }

    public func lunchLeft(_ d: String) -> String {
        t(en: "Lunch break · \(d) left", zh: "午休中 · 还有 \(d)", ja: "休憩中 · あと\(d)",
          ko: "점심시간 · \(d) 남음", es: "Almuerzo · quedan \(d)",
          fr: "Pause déjeuner · \(d) restantes", de: "Mittagspause · noch \(d)",
          pt: "Almoço · faltam \(d)", ms: "Rehat makan · \(d) lagi")
    }

    public var clockedOff: String {
        t(en: "Clocked off", zh: "已下班", ja: "退勤済み", ko: "퇴근함",
          es: "Jornada terminada", fr: "Journée terminée", de: "Feierabend",
          pt: "Expediente encerrado", ms: "Sudah balik")
    }

    public var setupIncomplete: String {
        t(en: "Setup incomplete", zh: "设置不完整", ja: "設定が未完了", ko: "설정 미완료",
          es: "Configuración incompleta", fr: "Configuration incomplète",
          de: "Einrichtung unvollständig", pt: "Configuração incompleta",
          ms: "Tetapan tidak lengkap")
    }

    // MARK: Menu bar

    public var menuBarSetSalary: String {
        t(en: "Set salary", zh: "设置薪资", ja: "給与を設定", ko: "급여 설정",
          es: "Configurar sueldo", fr: "Définir le salaire", de: "Gehalt festlegen",
          pt: "Definir salário", ms: "Tetapkan gaji")
    }

    public var menuBarDayOff: String {
        t(en: "Day off", zh: "休息中", ja: "休み", ko: "휴무",
          es: "Libre", fr: "Repos", de: "Frei", pt: "Folga", ms: "Cuti")
    }

    // MARK: Panel

    public var earnedToday: String {
        t(en: "Earned today", zh: "今日已赚", ja: "本日の収入", ko: "오늘 번 금액",
          es: "Ganado hoy", fr: "Gagné aujourd'hui", de: "Heute verdient",
          pt: "Ganho hoje", ms: "Pendapatan hari ini")
    }

    public var todayProgress: String {
        t(en: "Today", zh: "今日进度", ja: "本日", ko: "오늘",
          es: "Hoy", fr: "Aujourd'hui", de: "Heute", pt: "Hoje", ms: "Hari ini")
    }

    public var perSecond: String {
        t(en: "Per second", zh: "每秒", ja: "1秒あたり", ko: "초당",
          es: "Por segundo", fr: "Par seconde", de: "Pro Sekunde",
          pt: "Por segundo", ms: "Sesaat")
    }

    public var hourly: String {
        t(en: "Hourly", zh: "时薪", ja: "時給", ko: "시급",
          es: "Por hora", fr: "Par heure", de: "Pro Stunde", pt: "Por hora", ms: "Sejam")
    }

    public var fullDay: String {
        t(en: "Full day", zh: "满勤一天", ja: "1日分", ko: "하루치",
          es: "Día completo", fr: "Journée complète", de: "Ganzer Tag",
          pt: "Dia inteiro", ms: "Sehari penuh")
    }

    public var monthToDate: String {
        t(en: "This month", zh: "本月已累计", ja: "今月の累計", ko: "이번 달 누계",
          es: "Este mes", fr: "Ce mois-ci", de: "Diesen Monat",
          pt: "Este mês", ms: "Bulan ini")
    }

    public func workdaysDone(_ done: Int, _ total: Int) -> String {
        t(en: "\(done) of \(total) workdays done",
          zh: "已完成 \(done) / \(total) 个工作日",
          ja: "\(total)日中\(done)日完了",
          ko: "\(total)일 중 \(done)일 완료",
          es: "\(done) de \(total) días trabajados",
          fr: "\(done) sur \(total) jours travaillés",
          de: "\(done) von \(total) Arbeitstagen",
          pt: "\(done) de \(total) dias úteis",
          ms: "\(done) daripada \(total) hari kerja")
    }

    public var plusToday: String {
        t(en: "+ today", zh: "+ 今天", ja: "+ 本日", ko: "+ 오늘",
          es: "+ hoy", fr: "+ aujourd'hui", de: "+ heute", pt: "+ hoje", ms: "+ hari ini")
    }

    public var setupNotice: String {
        t(en: "Salary or working hours are not set yet",
          zh: "薪资或上下班时间还没填好",
          ja: "給与または勤務時間が未設定です",
          ko: "급여 또는 근무 시간이 설정되지 않았습니다",
          es: "El sueldo o el horario aún no están configurados",
          fr: "Le salaire ou les horaires ne sont pas encore définis",
          de: "Gehalt oder Arbeitszeiten sind noch nicht festgelegt",
          pt: "Salário ou horário ainda não configurados",
          ms: "Gaji atau waktu kerja belum ditetapkan")
    }

    public var settingsAction: String {
        t(en: "Settings…", zh: "设置…", ja: "設定…", ko: "설정…",
          es: "Ajustes…", fr: "Réglages…", de: "Einstellungen…",
          pt: "Ajustes…", ms: "Tetapan…")
    }

    public var quitAction: String {
        t(en: "Quit", zh: "退出", ja: "終了", ko: "종료",
          es: "Salir", fr: "Quitter", de: "Beenden", pt: "Sair", ms: "Keluar")
    }

    // MARK: Settings — salary

    public var sectionSalary: String {
        t(en: "Salary", zh: "薪资", ja: "給与", ko: "급여",
          es: "Sueldo", fr: "Salaire", de: "Gehalt", pt: "Salário", ms: "Gaji")
    }

    /// "Basic" rather than "monthly" since the allowance joined it: this is specifically
    /// the part unpaid leave is deducted from, and the label has to say which one it is.
    public var monthlySalary: String {
        t(en: "Basic salary", zh: "基本薪资", ja: "基本給", ko: "기본급",
          es: "Salario base", fr: "Salaire de base", de: "Grundgehalt",
          pt: "Salário base", ms: "Gaji pokok")
    }

    public var monthlyAllowance: String {
        t(en: "Allowance", zh: "津贴", ja: "手当", ko: "수당",
          es: "Complementos", fr: "Indemnités", de: "Zulagen",
          pt: "Subsídios", ms: "Elaun")
    }

    /// The one thing the user has to understand to fill the two fields in correctly.
    public var allowanceCaption: String {
        t(en: "Unpaid leave comes out of the basic only. The allowance is paid in full.",
          zh: "无薪假只从基本薪扣除，津贴照发全额。",
          ja: "無給休暇は基本給からのみ差し引かれ、手当は全額支給されます。",
          ko: "무급 휴가는 기본급에서만 공제되며, 수당은 전액 지급됩니다.",
          es: "El permiso sin sueldo se descuenta solo del salario base; los complementos se pagan íntegros.",
          fr: "Le congé sans solde est déduit du seul salaire de base ; les indemnités sont versées intégralement.",
          de: "Unbezahlter Urlaub wird nur vom Grundgehalt abgezogen; Zulagen werden voll gezahlt.",
          pt: "A licença sem vencimento é descontada apenas do salário base; os subsídios são pagos por inteiro.",
          ms: "Cuti tanpa gaji ditolak daripada gaji pokok sahaja; elaun dibayar penuh.")
    }

    /// Month-neutral on purpose: the figure follows whichever month the grid is showing,
    /// and that month is named directly beneath it.
    public var workdaysThisMonth: String {
        t(en: "Workdays", zh: "工作日", ja: "勤務日数", ko: "근무일",
          es: "Días laborables", fr: "Jours ouvrés", de: "Arbeitstage",
          pt: "Dias úteis", ms: "Hari kerja")
    }

    public func days(_ n: Int) -> String {
        t(en: "\(n) days", zh: "\(n) 天", ja: "\(n)日", ko: "\(n)일",
          es: "\(n) días", fr: "\(n) jours", de: "\(n) Tage", pt: "\(n) dias", ms: "\(n) hari")
    }

    public var derivedHourly: String {
        t(en: "Hourly rate", zh: "推算时薪", ja: "時給換算", ko: "시급 환산",
          es: "Tarifa por hora", fr: "Taux horaire", de: "Stundensatz",
          pt: "Valor por hora", ms: "Kadar sejam")
    }

    public var invalidNotice: String {
        t(en: "These settings cannot produce an hourly rate — check the salary, workdays and working hours.",
          zh: "当前设置算不出时薪，请检查薪资、工作日和上下班时间。",
          ja: "この設定では時給を計算できません。給与・勤務日・勤務時間を確認してください。",
          ko: "현재 설정으로는 시급을 계산할 수 없습니다. 급여, 근무일, 근무 시간을 확인하세요.",
          es: "Esta configuración no permite calcular una tarifa por hora — revisa el sueldo, los días y el horario.",
          fr: "Ces réglages ne permettent pas de calculer un taux horaire — vérifiez le salaire, les jours et les horaires.",
          de: "Mit diesen Einstellungen lässt sich kein Stundensatz berechnen — prüfe Gehalt, Arbeitstage und Arbeitszeit.",
          pt: "Estas configurações não permitem calcular um valor por hora — verifique o salário, os dias e o horário.",
          ms: "Tetapan ini tidak dapat mengira kadar sejam — semak gaji, hari kerja dan waktu kerja.")
    }

    public var salaryCaption: String {
        t(en: "The basic is divided by that month's paid workdays. A paid holiday leaves that count, so every day you do work is worth a little more; unpaid leave stays in it, so the month comes up short by that day.",
          zh: "基本薪 ÷ 该月的计薪工作日，就是每天的基本部分。带薪假期会从这个天数里剔除，所以你真正上班的每一天都更值钱；无薪假期仍留在里面，因此当月会少这一天的钱。",
          ja: "基本給をその月の有給勤務日数で割ったものが、一日あたりの基本分です。有給休暇はこの日数から外れるため、実際に働く一日一日の価値が上がります。無給休暇は日数に残るので、その分だけ月の合計が減ります。",
          ko: "기본급을 해당 월의 유급 근무일로 나눈 것이 하루치 기본 몫입니다. 유급 휴일은 이 일수에서 빠지므로 실제로 일하는 하루하루의 가치가 올라갑니다. 무급 휴가는 일수에 남아 그만큼 월 합계가 줄어듭니다.",
          es: "El salario base se divide entre los días laborables pagados de ese mes. Un festivo pagado sale de esa cuenta, así que cada día trabajado vale un poco más; el permiso sin sueldo permanece en ella, así que el mes queda corto por ese día.",
          fr: "Le salaire de base est divisé par les jours ouvrés payés de ce mois. Un jour férié payé sort de ce compte, donc chaque jour travaillé vaut un peu plus ; un congé non payé y reste, et le mois est amputé de cette journée.",
          de: "Das Grundgehalt wird durch die bezahlten Arbeitstage des Monats geteilt. Ein bezahlter Feiertag fällt aus dieser Zahl heraus, dadurch ist jeder gearbeitete Tag etwas mehr wert; unbezahlter Urlaub bleibt darin, der Monat fällt also um diesen Tag geringer aus.",
          pt: "O salário base é dividido pelos dias úteis pagos desse mês. Um feriado pago sai dessa contagem, então cada dia trabalhado vale um pouco mais; a folga sem pagamento permanece nela, então o mês fica menor nesse dia.",
          ms: "Gaji pokok dibahagi dengan hari kerja bergaji bulan itu. Cuti bergaji dikeluarkan daripada kiraan itu, jadi setiap hari anda bekerja bernilai sedikit lebih tinggi; cuti tanpa gaji kekal di dalamnya, jadi bulan itu berkurang sebanyak hari tersebut.")
    }

    // MARK: Settings — schedule

    public var sectionSchedule: String {
        t(en: "Hours", zh: "作息", ja: "勤務時間", ko: "근무 시간",
          es: "Horario", fr: "Horaires", de: "Arbeitszeit", pt: "Horário", ms: "Waktu kerja")
    }

    public var clockIn: String {
        t(en: "Clock in", zh: "上班", ja: "出勤", ko: "출근",
          es: "Entrada", fr: "Arrivée", de: "Arbeitsbeginn", pt: "Entrada", ms: "Masuk")
    }

    public var clockOff: String {
        t(en: "Clock off", zh: "下班", ja: "退勤", ko: "퇴근",
          es: "Salida", fr: "Départ", de: "Arbeitsende", pt: "Saída", ms: "Balik")
    }

    public var unpaidLunch: String {
        t(en: "Unpaid lunch break", zh: "午休不计薪", ja: "休憩は無給", ko: "점심시간 무급",
          es: "Almuerzo no remunerado", fr: "Pause déjeuner non payée",
          de: "Unbezahlte Mittagspause", pt: "Almoço não remunerado",
          ms: "Rehat makan tanpa gaji")
    }

    public var lunchStart: String {
        t(en: "Lunch starts", zh: "午休开始", ja: "休憩開始", ko: "점심 시작",
          es: "Inicio del almuerzo", fr: "Début de la pause", de: "Pause beginnt",
          pt: "Início do almoço", ms: "Rehat mula")
    }

    public var lunchEnd: String {
        t(en: "Lunch ends", zh: "午休结束", ja: "休憩終了", ko: "점심 종료",
          es: "Fin del almuerzo", fr: "Fin de la pause", de: "Pause endet",
          pt: "Fim do almoço", ms: "Rehat tamat")
    }

    public var paidPerDay: String {
        t(en: "Paid hours per day", zh: "每日计薪时长", ja: "1日の有給時間", ko: "하루 유급 시간",
          es: "Horas pagadas al día", fr: "Heures payées par jour",
          de: "Bezahlte Stunden pro Tag", pt: "Horas pagas por dia",
          ms: "Jam berbayar sehari")
    }

    public var overnightCaption: String {
        t(en: "Overnight shifts are not supported: clock-off must be later than clock-in.",
          zh: "暂不支持跨夜班次：下班时间必须晚于上班时间。",
          ja: "夜勤（日をまたぐ勤務）は非対応です。退勤時刻は出勤時刻より後にしてください。",
          ko: "야간 교대(자정을 넘는 근무)는 지원하지 않습니다. 퇴근 시간은 출근 시간보다 늦어야 합니다.",
          es: "Los turnos nocturnos no son compatibles: la salida debe ser posterior a la entrada.",
          fr: "Les postes de nuit ne sont pas pris en charge : le départ doit être après l'arrivée.",
          de: "Nachtschichten werden nicht unterstützt: Das Arbeitsende muss nach dem Arbeitsbeginn liegen.",
          pt: "Turnos noturnos não são suportados: a saída deve ser depois da entrada.",
          ms: "Syif merentas malam tidak disokong: waktu balik mesti lewat daripada waktu masuk.")
    }

    // MARK: Settings — workdays

    public func overtimeFor(_ d: String) -> String {
        t(en: "Overtime · \(d)", zh: "加班中 · \(d)", ja: "残業中 · \(d)", ko: "초과 근무 · \(d)",
          es: "Horas extra · \(d)", fr: "Heures sup. · \(d)", de: "Überstunden · \(d)",
          pt: "Hora extra · \(d)", ms: "Kerja lebih masa · \(d)")
    }

    public var sectionOvertime: String {
        t(en: "Overtime", zh: "加班", ja: "残業", ko: "초과 근무",
          es: "Horas extra", fr: "Heures supplémentaires", de: "Überstunden",
          pt: "Hora extra", ms: "Kerja lebih masa")
    }

    public var overtimeEnabled: String {
        t(en: "Keep counting after clock-off", zh: "下班后继续计薪", ja: "退勤後も計算を続ける",
          ko: "퇴근 후에도 계속 계산", es: "Seguir contando tras la salida",
          fr: "Continuer après la fin de journée", de: "Nach Feierabend weiterzählen",
          pt: "Continuar contando após a saída", ms: "Terus mengira selepas balik")
    }

    public var overtimeRate: String {
        t(en: "Rate multiplier", zh: "倍率", ja: "割増率", ko: "가산율",
          es: "Multiplicador", fr: "Coefficient", de: "Zuschlagsfaktor",
          pt: "Multiplicador", ms: "Pengganda kadar")
    }

    public var overtimeMax: String {
        t(en: "Stop after", zh: "最多计", ja: "上限", ko: "최대",
          es: "Detener tras", fr: "Arrêter après", de: "Stoppen nach",
          pt: "Parar após", ms: "Berhenti selepas")
    }

    public func hours(_ n: Int) -> String {
        t(en: "\(n) hours", zh: "\(n) 小时", ja: "\(n)時間", ko: "\(n)시간",
          es: "\(n) horas", fr: "\(n) heures", de: "\(n) Stunden",
          pt: "\(n) horas", ms: "\(n) jam")
    }

    public var overtimeCaption: String {
        t(en: "The app cannot tell when you actually left, so overtime stops at the limit above and never carries past midnight.",
          zh: "程序无法知道你实际几点离开，所以加班到上面的上限就停，也不会跨过午夜。",
          ja: "実際に退勤した時刻はアプリには分からないため、残業は上の上限で停止し、日付をまたぐこともありません。",
          ko: "앱은 실제 퇴근 시각을 알 수 없으므로 초과 근무는 위 한도에서 멈추며 자정을 넘기지 않습니다.",
          es: "La app no sabe cuándo te fuiste de verdad, así que las horas extra se detienen en el límite y nunca pasan de medianoche.",
          fr: "L'app ignore l'heure réelle de votre départ : les heures sup s'arrêtent à la limite ci-dessus et ne dépassent jamais minuit.",
          de: "Die App weiß nicht, wann du tatsächlich gegangen bist — Überstunden stoppen beim Limit oben und laufen nie über Mitternacht.",
          pt: "O app não sabe quando você realmente saiu, então a hora extra para no limite acima e nunca passa da meia-noite.",
          ms: "Aplikasi tidak tahu bila anda sebenarnya balik, jadi kerja lebih masa berhenti pada had di atas dan tidak melepasi tengah malam.")
    }

    public var menuBarShowRing: String {
        t(en: "Show progress ring", zh: "显示进度环", ja: "進捗リングを表示", ko: "진행 링 표시",
          es: "Mostrar anillo de progreso", fr: "Afficher l'anneau de progression",
          de: "Fortschrittsring anzeigen", pt: "Mostrar anel de progresso",
          ms: "Tunjuk gelang kemajuan")
    }

    public var menuBarShowSymbol: String {
        t(en: "Show currency symbol", zh: "显示货币符号", ja: "通貨記号を表示", ko: "통화 기호 표시",
          es: "Mostrar símbolo de moneda", fr: "Afficher le symbole monétaire",
          de: "Währungssymbol anzeigen", pt: "Mostrar símbolo da moeda",
          ms: "Tunjuk simbol mata wang")
    }

    public var menuBarHideAmount: String {
        t(en: "Hide amount in menu bar", zh: "在菜单栏隐藏金额",
          ja: "メニューバーで金額を隠す", ko: "메뉴 막대에서 금액 숨기기",
          es: "Ocultar el importe en la barra de menús",
          fr: "Masquer le montant dans la barre des menus",
          de: "Betrag in der Menüleiste ausblenden",
          pt: "Ocultar o valor na barra de menus",
          ms: "Sembunyikan jumlah pada bar menu")
    }

    // MARK: Dynamic Island

    /// Apple's own name for it, and localised the way Apple localises it: translated where
    /// they translate it, left alone where they do not.
    public var dynamicIsland: String {
        t(en: "Dynamic Island", zh: "灵动岛", ja: "ダイナミックアイランド",
          ko: "다이나믹 아일랜드", es: "Dynamic Island", fr: "Dynamic Island",
          de: "Dynamic Island", pt: "Dynamic Island", ms: "Dynamic Island")
    }

    /// Says what it shows and, more usefully, what it cannot: the clock keeps moving on its
    /// own because iOS animates it, and the figure stops the moment the app leaves the
    /// front. Better to say so than to let a stalled number look like a broken one.
    public var dynamicIslandCaption: String {
        t(en: "Shows today's earnings on the island and the lock screen. The clock keeps running on its own; the amount is from the last time the app was open.",
          zh: "在灵动岛和锁屏上显示今天赚到的钱。时间会自己走，金额停在最后一次打开应用的时候。",
          ja: "その日の収入をダイナミックアイランドとロック画面に表示する。時間は自動で進み、金額は最後にアプリを開いたときのもの。",
          ko: "오늘 번 금액을 다이나믹 아일랜드와 잠금 화면에 표시합니다. 시간은 알아서 흘러가고, 금액은 앱을 마지막으로 열었을 때 기준입니다.",
          es: "Muestra lo ganado hoy en la isla y en la pantalla de bloqueo. El reloj sigue solo; el importe es del último momento en que la app estuvo abierta.",
          fr: "Affiche les gains du jour sur l'île et sur l'écran verrouillé. L'horloge avance toute seule ; le montant date de la dernière ouverture de l'app.",
          de: "Zeigt den heutigen Verdienst auf der Insel und dem Sperrbildschirm. Die Uhr läuft von selbst weiter; der Betrag stammt vom letzten Mal, als die App offen war.",
          pt: "Mostra o ganho de hoje na ilha e no ecrã bloqueado. O relógio continua sozinho; o valor é da última vez que a app esteve aberta.",
          ms: "Menunjukkan pendapatan hari ini pada pulau dan skrin kunci. Jam terus berjalan sendiri; jumlahnya dari kali terakhir apl dibuka.")
    }

    public var openSystemSettings: String {
        t(en: "Open Settings", zh: "打开「设置」", ja: "設定を開く", ko: "설정 열기",
          es: "Abrir Ajustes", fr: "Ouvrir Réglages", de: "Einstellungen öffnen",
          pt: "Abrir Ajustes", ms: "Buka Tetapan")
    }

    /// The switch is off and not because of anything in this app. A control that silently
    /// does nothing is worse than one that says who is stopping it.
    public var dynamicIslandUnavailable: String {
        t(en: "iOS has Live Activities turned off for SalaryTicker. Turn them back on in the Settings app, under SalaryTicker.",
          zh: "iOS 关闭了 SalaryTicker 的实时活动。到「设置」里的 SalaryTicker 重新打开。",
          ja: "iOS 側で SalaryTicker のライブアクティビティがオフになっている。「設定」の SalaryTicker から戻せる。",
          ko: "iOS에서 SalaryTicker의 라이브 액티비티가 꺼져 있습니다. 설정 앱의 SalaryTicker에서 다시 켜세요.",
          es: "iOS tiene las Actividades en Vivo desactivadas para SalaryTicker. Vuelve a activarlas en Ajustes, dentro de SalaryTicker.",
          fr: "iOS a désactivé les activités en direct pour SalaryTicker. Réactivez-les dans Réglages, sous SalaryTicker.",
          de: "iOS hat Live-Aktivitäten für SalaryTicker deaktiviert. In den Einstellungen unter SalaryTicker wieder einschalten.",
          pt: "O iOS tem as Atividades Ao Vivo desativadas para o SalaryTicker. Volte a ativá-las nos Ajustes, em SalaryTicker.",
          ms: "iOS mematikan Aktiviti Langsung untuk SalaryTicker. Hidupkan semula dalam Tetapan, di bawah SalaryTicker.")
    }

    /// The panel's own one-click version of the setting above.
    public var hideAmountAction: String {
        t(en: "Hide amount", zh: "隐藏金额", ja: "金額を隠す", ko: "금액 숨기기",
          es: "Ocultar importe", fr: "Masquer le montant", de: "Betrag ausblenden",
          pt: "Ocultar valor", ms: "Sembunyikan jumlah")
    }

    public var showAmountAction: String {
        t(en: "Show amount", zh: "显示金额", ja: "金額を表示", ko: "금액 표시",
          es: "Mostrar importe", fr: "Afficher le montant", de: "Betrag einblenden",
          pt: "Mostrar valor", ms: "Tunjuk jumlah")
    }

    public var menuBarIconWhenIdle: String {
        t(en: "Icon only outside working hours", zh: "非工作时段只显示图标",
          ja: "勤務時間外はアイコンのみ", ko: "근무 시간 외에는 아이콘만",
          es: "Solo icono fuera del horario", fr: "Icône seule hors des horaires",
          de: "Außerhalb der Arbeitszeit nur Symbol", pt: "Apenas ícone fora do horário",
          ms: "Ikon sahaja di luar waktu kerja")
    }

    public var today: String {
        t(en: "today", zh: "今天", ja: "本日", ko: "오늘",
          es: "hoy", fr: "aujourd'hui", de: "heute", pt: "hoje", ms: "hari ini")
    }

    public var searchPlaceholder: String {
        t(en: "Search", zh: "搜索", ja: "検索", ko: "검색",
          es: "Buscar", fr: "Rechercher", de: "Suchen", pt: "Buscar", ms: "Cari")
    }

    public var changeAction: String {
        t(en: "Change…", zh: "更改…", ja: "変更…", ko: "변경…",
          es: "Cambiar…", fr: "Modifier…", de: "Ändern…", pt: "Alterar…", ms: "Tukar…")
    }

    public var sectionWorkdays: String {
        t(en: "Workdays", zh: "工作日", ja: "勤務日", ko: "근무일",
          es: "Días laborables", fr: "Jours ouvrés", de: "Arbeitstage",
          pt: "Dias úteis", ms: "Hari kerja")
    }

    /// Sunday-first, matching `Calendar`'s weekday numbering.
    public var weekdayInitials: [String] {
        switch language {
        case .english: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        case .chinese: ["日", "一", "二", "三", "四", "五", "六"]
        case .japanese: ["日", "月", "火", "水", "木", "金", "土"]
        case .korean: ["일", "월", "화", "수", "목", "금", "토"]
        case .spanish: ["Do", "Lu", "Ma", "Mi", "Ju", "Vi", "Sá"]
        case .french: ["Di", "Lu", "Ma", "Me", "Je", "Ve", "Sa"]
        case .german: ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        case .portuguese: ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
        case .malay: ["Ah", "Is", "Se", "Ra", "Kh", "Ju", "Sa"]
        }
    }

    // MARK: Goals

    public var sectionGoals: String {
        t(en: "Goals", zh: "目标", ja: "目標", ko: "목표",
          es: "Objetivos", fr: "Objectifs", de: "Ziele", pt: "Metas", ms: "Sasaran")
    }

    public var goalNamePlaceholder: String {
        t(en: "What is it?", zh: "想买什么？", ja: "何が欲しい？", ko: "무엇을 사고 싶나요?",
          es: "¿Qué es?", fr: "C'est quoi ?", de: "Was ist es?", pt: "O que é?",
          ms: "Apa itu?")
    }

    public var goalPrice: String {
        t(en: "Price", zh: "价格", ja: "価格", ko: "가격",
          es: "Precio", fr: "Prix", de: "Preis", pt: "Preço", ms: "Harga")
    }

    public var addGoal: String {
        t(en: "Add goal", zh: "添加目标", ja: "目標を追加", ko: "목표 추가",
          es: "Añadir objetivo", fr: "Ajouter un objectif", de: "Ziel hinzufügen",
          pt: "Adicionar meta", ms: "Tambah sasaran")
    }

    /// Title of the sheet that collects a goal before it exists.
    public var newGoal: String {
        t(en: "New goal", zh: "新目标", ja: "新しい目標", ko: "새 목표",
          es: "Nuevo objetivo", fr: "Nouvel objectif", de: "Neues Ziel",
          pt: "Nova meta", ms: "Sasaran baharu")
    }

    /// The settings list no longer adds goals, so its empty state says where they come
    /// from instead of inviting a tap that is not there any more.
    public var goalsAddedFromMain: String {
        t(en: "Nothing on the list yet. Goals are added from the main screen; this is where you edit and reorder them.",
          zh: "还没有目标。目标在主界面添加，这里用来编辑和排序。",
          ja: "まだ目標がない。目標はメイン画面から追加する。ここは編集と並べ替えのための場所。",
          ko: "아직 목표가 없습니다. 목표는 메인 화면에서 추가하고, 여기서는 수정하고 순서를 바꿉니다.",
          es: "Todavía no hay nada. Los objetivos se añaden desde la pantalla principal; aquí se editan y se reordenan.",
          fr: "Rien pour l'instant. Les objectifs s'ajoutent depuis l'écran principal ; ici on les modifie et on les réordonne.",
          de: "Noch nichts da. Ziele werden auf dem Hauptbildschirm angelegt; hier werden sie bearbeitet und sortiert.",
          pt: "Ainda não há nada. As metas são adicionadas no ecrã principal; aqui edita-as e reordena-as.",
          ms: "Belum ada apa-apa. Sasaran ditambah dari skrin utama; di sini anda menyuntingnya dan menyusun semula.")
    }

    public var showInPanel: String {
        t(en: "Show in panel", zh: "显示在小窗口", ja: "パネルに表示", ko: "패널에 표시",
          es: "Mostrar en el panel", fr: "Afficher dans le panneau",
          de: "Im Panel anzeigen", pt: "Mostrar no painel", ms: "Tunjuk dalam panel")
    }

    public var noGoalsYet: String {
        // An empty state that names the next move, rather than only reporting the absence.
        t(en: "Nothing on the list yet. Add something you are saving for and it will be priced in working days.",
          zh: "还没有目标。加一样你想攒钱买的东西，它会被换算成多少个工作日。",
          ja: "まだ目標がありません。買いたいものを追加すると、何営業日ぶんかに換算されます。",
          ko: "아직 목표가 없습니다. 사고 싶은 것을 추가하면 근무일 수로 환산해 드립니다.",
          es: "Todavía no hay nada. Añade algo para lo que estés ahorrando y se te dirá en días de trabajo.",
          fr: "Rien pour l'instant. Ajoutez ce pour quoi vous économisez : ce sera chiffré en jours de travail.",
          de: "Noch nichts auf der Liste. Trag ein, wofür du sparst, und es wird in Arbeitstagen ausgerechnet.",
          pt: "Nada na lista ainda. Adicione algo para o qual esteja a poupar e será convertido em dias de trabalho.",
          ms: "Belum ada sasaran. Tambah sesuatu yang anda sedang kumpul duit untuknya, dan ia akan dikira dalam hari kerja.")
    }

    public func workdaysCost(_ days: String) -> String {
        t(en: "\(days) working days", zh: "\(days) 个工作日", ja: "\(days)営業日",
          ko: "근무일 \(days)일", es: "\(days) días de trabajo",
          fr: "\(days) jours de travail", de: "\(days) Arbeitstage",
          pt: "\(days) dias de trabalho", ms: "\(days) hari kerja")
    }

    public func readyBy(_ when: String) -> String {
        t(en: "Ready \(when)", zh: "\(when) 到手", ja: "\(when)に達成", ko: "\(when) 달성",
          es: "Listo \(when)", fr: "Prêt \(when)", de: "Fertig \(when)",
          pt: "Pronto \(when)", ms: "Siap \(when)")
    }

    public var goalReached: String {
        t(en: "Paid for", zh: "已攒够", ja: "達成済み", ko: "다 모았어요",
          es: "Ya lo tienes", fr: "C'est payé", de: "Bezahlt", pt: "Já dá",
          ms: "Sudah cukup")
    }

    public var goalOutOfReach: String {
        t(en: "More than five years away", zh: "超过五年", ja: "5年以上先",
          ko: "5년 이상", es: "A más de cinco años", fr: "À plus de cinq ans",
          de: "Mehr als fünf Jahre entfernt", pt: "A mais de cinco anos",
          ms: "Lebih lima tahun lagi")
    }

    public var doneAction: String {
        t(en: "Done", zh: "完成", ja: "完了", ko: "완료",
          es: "Listo", fr: "OK", de: "Fertig", pt: "Concluído", ms: "Selesai")
    }

    /// The screen's own title. `settingsAction` carries the ellipsis that means "opens a
    /// window", which is right on a menu item and wrong at the top of the thing it opened.
    public var settingsTitle: String {
        t(en: "Settings", zh: "设置", ja: "設定", ko: "설정",
          es: "Ajustes", fr: "Réglages", de: "Einstellungen",
          pt: "Definições", ms: "Tetapan")
    }

    // MARK: Moving settings between machines

    public var sendToPhone: String {
        t(en: "Send to phone", zh: "发送到手机", ja: "iPhone に送る", ko: "iPhone으로 보내기",
          es: "Enviar al teléfono", fr: "Envoyer au téléphone",
          de: "Ans iPhone senden", pt: "Enviar para o telemóvel", ms: "Hantar ke telefon")
    }

    public var sendToPhoneCaption: String {
        t(en: "Scan this with the iPhone app to copy every setting across. The code holds your salary — it goes camera to phone and nowhere else.",
          zh: "用 iPhone 上的 app 扫这个码，所有设置就过去了。码里含有你的薪资 —— 它只从摄像头进手机，不经过任何别处。",
          ja: "iPhone アプリでこれを読み取ると、設定がすべて移ります。コードには給与が入っている。カメラから iPhone へ渡るだけで、どこにも送られない。",
          ko: "iPhone 앱으로 이 코드를 스캔하면 모든 설정이 넘어갑니다. 코드에는 급여가 들어 있으며, 카메라에서 iPhone으로만 전달되고 다른 곳으로는 가지 않습니다.",
          es: "Escanéalo con la app del iPhone para llevarte todos los ajustes. El código contiene tu sueldo: va de la cámara al teléfono y a ningún otro sitio.",
          fr: "Scannez-le avec l'app iPhone pour y recopier tous les réglages. Le code contient votre salaire : il va de l'appareil photo au téléphone, et nulle part ailleurs.",
          de: "Mit der iPhone-App scannen, um alle Einstellungen zu übernehmen. Der Code enthält dein Gehalt — er geht von der Kamera aufs Telefon und sonst nirgendwohin.",
          pt: "Digitalize com a app do iPhone para copiar todas as definições. O código contém o seu salário: vai da câmara para o telemóvel e mais nada.",
          ms: "Imbas ini dengan app iPhone untuk menyalin semua tetapan. Kod ini mengandungi gaji anda — ia pergi dari kamera ke telefon sahaja.")
    }

    public var importTitle: String {
        t(en: "Settings from your Mac", zh: "来自 Mac 的设置", ja: "Mac からの設定",
          ko: "Mac에서 온 설정", es: "Ajustes desde tu Mac", fr: "Réglages depuis votre Mac",
          de: "Einstellungen von deinem Mac", pt: "Definições do seu Mac",
          ms: "Tetapan daripada Mac anda")
    }

    /// Says what will be lost, because importing replaces everything at once.
    public var importMessage: String {
        t(en: "This replaces every setting on this phone.",
          zh: "这会替换掉这台手机上的全部设置。",
          ja: "この iPhone の設定はすべて置き換わります。",
          ko: "이 iPhone의 모든 설정이 대체됩니다.",
          es: "Esto sustituye todos los ajustes de este teléfono.",
          fr: "Cela remplace tous les réglages de ce téléphone.",
          de: "Das ersetzt sämtliche Einstellungen auf diesem Telefon.",
          pt: "Isto substitui todas as definições deste telemóvel.",
          ms: "Ini menggantikan semua tetapan pada telefon ini.")
    }

    public var importAction: String {
        t(en: "Replace settings", zh: "替换设置", ja: "設定を置き換える", ko: "설정 바꾸기",
          es: "Sustituir ajustes", fr: "Remplacer les réglages", de: "Einstellungen ersetzen",
          pt: "Substituir definições", ms: "Ganti tetapan")
    }

    public var importUnreadable: String {
        t(en: "That link is not settings this app can read.",
          zh: "这个链接不是本 app 能读的设置。",
          ja: "このリンクはこのアプリが読める設定ではありません。",
          ko: "이 링크는 이 앱이 읽을 수 있는 설정이 아닙니다.",
          es: "Ese enlace no son ajustes que esta app pueda leer.",
          fr: "Ce lien ne contient pas de réglages lisibles par cette app.",
          de: "Dieser Link enthält keine Einstellungen, die diese App lesen kann.",
          pt: "Essa ligação não são definições que esta app consiga ler.",
          ms: "Pautan itu bukan tetapan yang app ini boleh baca.")
    }

    // MARK: Settings — goals, destructive

    /// Deleting a goal is the only irreversible thing in the app, so it asks first.
    public func deleteGoalTitle(_ name: String) -> String {
        t(en: "Delete “\(name)”?", zh: "删除「\(name)」？", ja: "「\(name)」を削除しますか？",
          ko: "“\(name)”을(를) 삭제할까요?", es: "¿Eliminar «\(name)»?",
          fr: "Supprimer « \(name) » ?", de: "„\(name)“ löschen?",
          pt: "Eliminar “\(name)”?", ms: "Padam “\(name)”?")
    }

    public var deleteGoalMessage: String {
        t(en: "This cannot be undone.", zh: "此操作无法撤销。", ja: "この操作は取り消せません。",
          ko: "이 작업은 되돌릴 수 없습니다.", es: "Esto no se puede deshacer.",
          fr: "Cette action est irréversible.", de: "Das lässt sich nicht rückgängig machen.",
          pt: "Isto não pode ser anulado.", ms: "Tindakan ini tidak boleh dibatalkan.")
    }

    public var deleteAction: String {
        t(en: "Delete", zh: "删除", ja: "削除", ko: "삭제",
          es: "Eliminar", fr: "Supprimer", de: "Löschen", pt: "Eliminar", ms: "Padam")
    }

    public var cancelAction: String {
        t(en: "Cancel", zh: "取消", ja: "キャンセル", ko: "취소",
          es: "Cancelar", fr: "Annuler", de: "Abbrechen", pt: "Cancelar", ms: "Batal")
    }

    /// The empty half-typed goal a fresh row starts as.
    public var goalNeedsDetails: String {
        t(en: "Name it and give it a price to see what it costs.",
          zh: "填上名字和价格，才能算出它值多少工作日。",
          ja: "名前と価格を入れると、何日ぶんの仕事になるかが出ます。",
          ko: "이름과 가격을 넣으면 며칠치 일인지 알려줍니다.",
          es: "Ponle nombre y precio para ver lo que cuesta.",
          fr: "Donnez-lui un nom et un prix pour voir ce qu'il coûte.",
          de: "Name und Preis eintragen, dann steht da, was es kostet.",
          pt: "Dê-lhe um nome e um preço para ver quanto custa.",
          ms: "Beri nama dan harga untuk melihat berapa kosnya.")
    }

    /// Where a goal sits in the funding queue, for screen readers.
    public func queuePosition(_ index: Int, _ total: Int) -> String {
        t(en: "Position \(index) of \(total)", zh: "第 \(index) 位，共 \(total) 位",
          ja: "\(total) 件中 \(index) 番目", ko: "\(total)개 중 \(index)번째",
          es: "Posición \(index) de \(total)", fr: "Position \(index) sur \(total)",
          de: "Position \(index) von \(total)", pt: "Posição \(index) de \(total)",
          ms: "Kedudukan \(index) daripada \(total)")
    }

    public var moveGoalUp: String {
        t(en: "Move up", zh: "上移", ja: "上へ", ko: "위로",
          es: "Subir", fr: "Monter", de: "Nach oben", pt: "Mover para cima", ms: "Naik")
    }

    public var moveGoalDown: String {
        t(en: "Move down", zh: "下移", ja: "下へ", ko: "아래로",
          es: "Bajar", fr: "Descendre", de: "Nach unten", pt: "Mover para baixo", ms: "Turun")
    }

    /// The one rule a user has to know now that goals compete for the same money.
    public var goalsPriorityCaption: String {
        t(en: "Reorder with the arrows, or by dragging. Money fills the list from the top: a goal only starts filling once the ones above it are paid for.",
          zh: "用箭头或拖动调整顺序。钱从列表顶部往下填：上面的目标付清之后，下面的才开始攒。",
          ja: "矢印またはドラッグで並べ替えられます。お金はリストの上から順に入ります。上の目標が払い終わるまで、下の目標は貯まり始めません。",
          ko: "화살표나 끌기로 순서를 바꿀 수 있습니다. 돈은 목록 위에서부터 채워지며, 위의 목표를 다 채운 뒤에야 아래 목표가 모이기 시작합니다.",
          es: "Reordena con las flechas o arrastrando. El dinero llena la lista desde arriba: un objetivo no empieza a llenarse hasta que los de encima están pagados.",
          fr: "Réordonnez avec les flèches ou par glisser-déposer. L'argent remplit la liste par le haut : un objectif ne commence à se remplir qu'une fois ceux du dessus payés.",
          de: "Mit den Pfeilen oder per Ziehen umsortieren. Das Geld füllt die Liste von oben: ein Ziel beginnt sich erst zu füllen, wenn die darüber bezahlt sind.",
          pt: "Reordene com as setas ou arrastando. O dinheiro preenche a lista de cima para baixo: um objetivo só começa a encher depois de pagos os que estão acima.",
          ms: "Susun semula dengan anak panah atau dengan menyeret. Wang mengisi senarai dari atas: sesuatu matlamat hanya mula terisi setelah yang di atasnya selesai dibayar.")
    }

    public var goalsCaption: String {
        t(en: "A price becomes a number of working days, and a date the schedule says you will have it. The date holds still while you work — only changing your schedule moves it.",
          zh: "价格会换算成工作日数，以及按你的作息推算的到手日期。上班时这个日期不会动 —— 只有改作息或请假才会推迟它。",
          ja: "価格を営業日数と、勤務予定から算出した達成日に換算します。働いている限り日付は動きません。動くのは勤務設定を変えたときだけです。",
          ko: "가격을 근무일 수와, 일정에 따라 도달할 날짜로 환산합니다. 일하는 동안 날짜는 그대로이며, 일정을 바꿀 때만 움직입니다.",
          es: "Un precio se convierte en días de trabajo y en la fecha en que el horario dice que lo tendrás. La fecha no se mueve mientras trabajas: solo cambiarla el horario la desplaza.",
          fr: "Un prix devient un nombre de jours de travail et la date à laquelle vos horaires disent que vous l'aurez. Cette date ne bouge pas tant que vous travaillez : seul un changement d'horaires la décale.",
          de: "Ein Preis wird zu Arbeitstagen und zu dem Datum, an dem dein Zeitplan sagt, dass du es hast. Das Datum bleibt stehen, solange du arbeitest — nur eine Änderung am Zeitplan verschiebt es.",
          pt: "Um preço vira dias de trabalho e a data em que o seu horário diz que você o terá. A data não se move enquanto você trabalha — só mudar o horário a desloca.",
          ms: "Harga bertukar menjadi bilangan hari kerja, dan tarikh yang jadual anda kata anda akan memilikinya. Tarikh itu tidak bergerak selagi anda bekerja — hanya perubahan jadual menggesernya.")
    }

    // MARK: Settings — display

    public var legendWorked: String {
        t(en: "Worked", zh: "已完成", ja: "完了", ko: "완료",
          es: "Trabajado", fr: "Travaillé", de: "Gearbeitet", pt: "Trabalhado",
          ms: "Selesai")
    }

    public var legendUpcoming: String {
        t(en: "Upcoming", zh: "待完成", ja: "予定", ko: "예정",
          es: "Pendiente", fr: "À venir", de: "Ausstehend", pt: "Pendente",
          ms: "Akan datang")
    }

    public var previousMonth: String {
        t(en: "Previous month", zh: "上个月", ja: "前の月", ko: "이전 달",
          es: "Mes anterior", fr: "Mois précédent", de: "Vorheriger Monat",
          pt: "Mês anterior", ms: "Bulan sebelumnya")
    }

    public var nextMonth: String {
        t(en: "Next month", zh: "下个月", ja: "次の月", ko: "다음 달",
          es: "Mes siguiente", fr: "Mois suivant", de: "Nächster Monat",
          pt: "Próximo mês", ms: "Bulan seterusnya")
    }

    public var backToThisMonth: String {
        t(en: "Back to this month", zh: "回到本月", ja: "今月に戻る", ko: "이번 달로",
          es: "Volver a este mes", fr: "Revenir à ce mois", de: "Zurück zu diesem Monat",
          pt: "Voltar a este mês", ms: "Kembali ke bulan ini")
    }

    public var halfDay: String {
        t(en: "Half day", zh: "半天", ja: "半日", ko: "반일",
          es: "Medio día", fr: "Demi-journée", de: "Halber Tag", pt: "Meio dia",
          ms: "Setengah hari")
    }

    public var weekdayHint: String {
        t(en: "Click a weekday: off → full day → half day.",
          zh: "点星期：休息 → 整天 → 半天。",
          ja: "曜日をクリック：休み → 全日 → 半日。",
          ko: "요일 클릭: 휴무 → 종일 → 반일.",
          es: "Clic en un día: libre → completo → medio.",
          fr: "Clic sur un jour : repos → complet → demi.",
          de: "Wochentag klicken: frei → ganz → halb.",
          pt: "Clique num dia: folga → inteiro → meio.",
          ms: "Klik hari: cuti → penuh → separuh.")
    }

    public var legendPaidLeave: String {
        t(en: "Paid off", zh: "带薪休", ja: "有給休", ko: "유급 휴무",
          es: "Libre pagado", fr: "Congé payé", de: "Bezahlt frei",
          pt: "Folga paga", ms: "Cuti bergaji")
    }

    public var legendUnpaidLeave: String {
        t(en: "Unpaid", zh: "无薪休", ja: "無給休", ko: "무급 휴무",
          es: "Sin sueldo", fr: "Non payé", de: "Unbezahlt",
          pt: "Sem pagamento", ms: "Tanpa gaji")
    }

    public func daysOff(_ n: Int) -> String {
        t(en: "\(n) off", zh: "\(n) 天休假", ja: "休み\(n)日", ko: "휴무 \(n)일",
          es: "\(n) libres", fr: "\(n) en congé", de: "\(n) frei",
          pt: "\(n) de folga", ms: "\(n) cuti")
    }

    public var calendarHint: String {
        t(en: "Click a date: workday → paid holiday → unpaid leave.",
          zh: "点日期：工作日 → 带薪休 → 无薪休。",
          ja: "日付をクリック：勤務日 → 有給休 → 無給休。",
          ko: "날짜 클릭: 근무일 → 유급 휴무 → 무급 휴무.",
          es: "Clic en una fecha: laborable → festivo pagado → sin sueldo.",
          fr: "Clic sur une date : travaillé → congé payé → non payé.",
          de: "Datum klicken: Arbeitstag → bezahlt frei → unbezahlt.",
          pt: "Clique numa data: útil → feriado pago → sem pagamento.",
          ms: "Klik tarikh: hari kerja → cuti bergaji → tanpa gaji.")
    }

    public var sectionDisplay: String {
        t(en: "Display", zh: "显示", ja: "表示", ko: "표시",
          es: "Pantalla", fr: "Affichage", de: "Anzeige", pt: "Exibição", ms: "Paparan")
    }

    /// Title of the settings tab holding display and system preferences.
    public var sectionGeneral: String {
        t(en: "General", zh: "通用", ja: "一般", ko: "일반",
          es: "General", fr: "Général", de: "Allgemein", pt: "Geral", ms: "Umum")
    }

    public var languageLabel: String {
        t(en: "Language", zh: "语言", ja: "言語", ko: "언어",
          es: "Idioma", fr: "Langue", de: "Sprache", pt: "Idioma", ms: "Bahasa")
    }

    public var timeZoneLabel: String {
        t(en: "Time zone", zh: "时区", ja: "タイムゾーン", ko: "시간대",
          es: "Zona horaria", fr: "Fuseau horaire", de: "Zeitzone",
          pt: "Fuso horário", ms: "Zon waktu")
    }

    public var systemTimeZone: String {
        t(en: "System", zh: "跟随系统", ja: "システムに従う", ko: "시스템 설정",
          es: "Del sistema", fr: "Système", de: "System", pt: "Do sistema",
          ms: "Ikut sistem")
    }

    public var timeZoneCaption: String {
        t(en: "Pick a zone if your working hours belong somewhere other than this Mac's clock — the whole schedule is then read in that zone.",
          zh: "如果你的上下班时间属于另一个地区，而不是这台 Mac 的时钟，就选一个时区 —— 整个作息都会按那个时区解读。",
          ja: "勤務時間がこの Mac の時計とは別の地域のものである場合はタイムゾーンを選んでください。勤務設定全体がそのタイムゾーンで解釈されます。",
          ko: "근무 시간이 이 Mac의 시계가 아닌 다른 지역 기준이라면 시간대를 선택하세요. 전체 일정이 해당 시간대로 해석됩니다.",
          es: "Elige una zona si tu horario pertenece a un lugar distinto del reloj de este Mac — todo el horario se leerá en esa zona.",
          fr: "Choisissez un fuseau si vos horaires relèvent d'un autre lieu que l'horloge de ce Mac — tout l'horaire sera alors lu dans ce fuseau.",
          de: "Wähle eine Zeitzone, wenn deine Arbeitszeiten zu einem anderen Ort als der Uhr dieses Macs gehören — der gesamte Zeitplan wird dann in dieser Zone gelesen.",
          pt: "Escolha um fuso se o seu horário pertence a outro lugar que não o relógio deste Mac — todo o horário será lido nesse fuso.",
          ms: "Pilih zon waktu jika waktu kerja anda mengikut tempat lain, bukan jam Mac ini — keseluruhan jadual akan dibaca dalam zon itu.")
    }

    public var currencySymbol: String {
        t(en: "Currency symbol", zh: "货币符号", ja: "通貨記号", ko: "통화 기호",
          es: "Símbolo de moneda", fr: "Symbole monétaire", de: "Währungssymbol",
          pt: "Símbolo da moeda", ms: "Simbol mata wang")
    }

    public var decimals: String {
        t(en: "Decimals", zh: "小数位", ja: "小数点以下の桁数", ko: "소수점 자리",
          es: "Decimales", fr: "Décimales", de: "Nachkommastellen",
          pt: "Casas decimais", ms: "Titik perpuluhan")
    }

    public var menuBarPreview: String {
        t(en: "Menu bar preview", zh: "菜单栏预览", ja: "メニューバーのプレビュー",
          ko: "메뉴 막대 미리보기", es: "Vista previa", fr: "Aperçu", de: "Vorschau",
          pt: "Pré-visualização", ms: "Pratonton bar menu")
    }

    // MARK: Settings — system

    public var sectionSystem: String {
        t(en: "System", zh: "系统", ja: "システム", ko: "시스템",
          es: "Sistema", fr: "Système", de: "System", pt: "Sistema", ms: "Sistem")
    }

    public var launchAtLogin: String {
        t(en: "Launch at login", zh: "开机自动启动", ja: "ログイン時に起動", ko: "로그인 시 실행",
          es: "Abrir al iniciar sesión", fr: "Lancer à l'ouverture de session",
          de: "Beim Anmelden starten", pt: "Abrir ao iniciar sessão",
          ms: "Lancar semasa log masuk")
    }

    public var launchNeedsApproval: String {
        t(en: "Approve SalaryTicker in System Settings › General › Login Items to finish enabling this.",
          zh: "还需在「系统设置 › 通用 › 登录项」中批准 SalaryTicker，开机自启才会生效。",
          ja: "「システム設定 › 一般 › ログイン項目」で SalaryTicker を許可すると有効になります。",
          ko: "「시스템 설정 › 일반 › 로그인 항목」에서 SalaryTicker를 승인해야 적용됩니다.",
          es: "Aprueba SalaryTicker en Ajustes del Sistema › General › Ítems de inicio para activarlo.",
          fr: "Autorisez SalaryTicker dans Réglages Système › Général › Ouverture pour terminer l'activation.",
          de: "Bestätige SalaryTicker in Systemeinstellungen › Allgemein › Anmeldeobjekte, um dies zu aktivieren.",
          pt: "Aprove o SalaryTicker em Ajustes do Sistema › Geral › Itens de Início para concluir.",
          ms: "Benarkan SalaryTicker dalam Tetapan Sistem › Umum › Item Log Masuk untuk mengaktifkannya.")
    }

    public var notBundledCaption: String {
        t(en: "Launch SalaryTicker.app from /Applications to enable this.",
          zh: "从「应用程序」里启动 SalaryTicker.app 才能设置开机自启。",
          ja: "この設定を使うには /Applications から SalaryTicker.app を起動してください。",
          ko: "이 기능을 사용하려면 /Applications에서 SalaryTicker.app을 실행하세요.",
          es: "Abre SalaryTicker.app desde /Applications para activarlo.",
          fr: "Lancez SalaryTicker.app depuis /Applications pour l'activer.",
          de: "Starte SalaryTicker.app aus /Applications, um dies zu aktivieren.",
          pt: "Abra o SalaryTicker.app a partir de /Applications para ativar.",
          ms: "Lancarkan SalaryTicker.app dari /Applications untuk mengaktifkannya.")
    }

    public var notBundledError: String {
        t(en: "Move SalaryTicker.app into /Applications before enabling launch at login.",
          zh: "需要先把 SalaryTicker.app 拖进「应用程序」再开启开机自启。",
          ja: "ログイン時起動を有効にする前に SalaryTicker.app を /Applications に移動してください。",
          ko: "로그인 시 실행을 켜기 전에 SalaryTicker.app을 /Applications로 옮기세요.",
          es: "Mueve SalaryTicker.app a /Applications antes de activar el inicio automático.",
          fr: "Déplacez SalaryTicker.app dans /Applications avant d'activer le lancement à l'ouverture de session.",
          de: "Verschiebe SalaryTicker.app nach /Applications, bevor du den Start beim Anmelden aktivierst.",
          pt: "Mova o SalaryTicker.app para /Applications antes de ativar a abertura ao iniciar sessão.",
          ms: "Pindahkan SalaryTicker.app ke /Applications sebelum mengaktifkan lancar semasa log masuk.")
    }
}
