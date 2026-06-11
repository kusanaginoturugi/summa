Output assets/demo-ja.gif

Set Shell "bash"
Set FontSize 28
Set Width 1200
Set Height 600

Type "/tmp/invoice-demo generate --from '株式会社テスト' \" Enter
Type "  --to '山田太郎' \" Enter
Type "  --item '作業費' \" Enter
Type "  --quantity 2 \" Enter
Type "  --rate 25000 \" Enter
Type "  --currency JPY \" Enter
Type "  --note '備考です'" Enter

Sleep 3s
