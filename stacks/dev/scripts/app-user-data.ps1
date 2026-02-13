$pageHtml = @'
<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>brainCTL</title>
    <style>
      :root {
        color-scheme: dark;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
        background: radial-gradient(circle at 20% 20%, #2f3fb5 0%, #111827 45%, #05070f 100%);
        color: #e5e7eb;
      }
      .card {
        width: min(780px, 92vw);
        padding: 44px 38px;
        border-radius: 22px;
        border: 1px solid rgba(99, 102, 241, 0.35);
        background: rgba(17, 24, 39, 0.72);
        backdrop-filter: blur(8px);
        box-shadow: 0 25px 70px rgba(30, 64, 175, 0.35);
      }
      .badge {
        display: inline-block;
        margin-bottom: 16px;
        padding: 6px 12px;
        border-radius: 999px;
        background: rgba(79, 70, 229, 0.22);
        border: 1px solid rgba(129, 140, 248, 0.45);
        color: #c7d2fe;
        font-size: 12px;
        letter-spacing: .06em;
        text-transform: uppercase;
      }
      h1 {
        margin: 0;
        font-size: clamp(36px, 7vw, 72px);
        line-height: 1.02;
        letter-spacing: -0.04em;
        text-align: center;
      }
      .brand {
        background: linear-gradient(90deg, #a5b4fc 0%, #60a5fa 40%, #22d3ee 100%);
        -webkit-background-clip: text;
        background-clip: text;
        color: transparent;
      }
      p {
        margin: 16px 0 0;
        text-align: center;
        font-size: clamp(15px, 2.4vw, 20px);
        color: #cbd5e1;
      }
      .footer {
        margin-top: 22px;
        text-align: center;
        font-size: 13px;
        color: #93c5fd;
      }
    </style>
  </head>
  <body>
    <main class="card">
      <span class="badge">Platform Engineering</span>
      <h1><span class="brand">brainCTL</span></h1>
      <p>Infra de produto em ação — stack provisionada com sucesso.</p>
      <div class="footer">AWS + Terraform + Go</div>
    </main>
  </body>
</html>
'@

$ErrorActionPreference = "Stop"
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
New-Item -ItemType Directory -Force -Path "C:\inetpub\wwwroot" | Out-Null
Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value $pageHtml -Encoding UTF8
Restart-Service W3SVC