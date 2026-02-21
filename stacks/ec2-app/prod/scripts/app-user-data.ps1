$pageHtml = @'
<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>brainctl | Infraestrutura como Produto</title>
    <style>
      :root {
        --bg: #070b17;
        --bg-soft: #0f172a;
        --card: #111a30cc;
        --line: #334155;
        --text: #e2e8f0;
        --muted: #94a3b8;
        --accent: #38bdf8;
        --accent-2: #818cf8;
        --ok: #22c55e;
      }
      * { box-sizing: border-box; }
      html, body { margin: 0; }
      body {
        font-family: "Segoe UI", Inter, system-ui, -apple-system, sans-serif;
        color: var(--text);
        background:
          radial-gradient(circle at 10% 10%, #1e293b 0%, transparent 45%),
          radial-gradient(circle at 90% 20%, #1d4ed8 0%, transparent 35%),
          linear-gradient(160deg, #020617 0%, #0b1120 60%, #020617 100%);
      }
      .container { width: min(1100px, 92vw); margin: 0 auto; }
      .hero {
        padding: 58px 0 26px;
      }
      .tag {
        display: inline-block;
        padding: 8px 14px;
        border: 1px solid #334155;
        border-radius: 999px;
        font-size: 12px;
        letter-spacing: .08em;
        text-transform: uppercase;
        color: #cbd5e1;
        background: rgba(15, 23, 42, .75);
      }
      h1 {
        margin: 18px 0 14px;
        font-size: clamp(34px, 6vw, 64px);
        line-height: 1.05;
        letter-spacing: -0.03em;
      }
      .brand {
        background: linear-gradient(90deg, var(--accent-2), var(--accent));
        -webkit-background-clip: text;
        background-clip: text;
        color: transparent;
      }
      .lead {
        margin: 0;
        max-width: 860px;
        color: var(--muted);
        font-size: clamp(16px, 2.1vw, 20px);
        line-height: 1.55;
      }
      .grid {
        display: grid;
        gap: 18px;
        grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
        margin: 28px 0 12px;
      }
      .card {
        border: 1px solid rgba(148, 163, 184, .25);
        background: var(--card);
        border-radius: 18px;
        padding: 18px;
        backdrop-filter: blur(6px);
      }
      .card h3 {
        margin: 0 0 8px;
        font-size: 16px;
      }
      .card p { margin: 0; color: var(--muted); line-height: 1.45; font-size: 14px; }
      .section {
        margin-top: 24px;
        border: 1px solid rgba(148, 163, 184, .22);
        background: rgba(15, 23, 42, .62);
        border-radius: 18px;
        padding: 20px;
      }
      .section h2 { margin: 0 0 14px; font-size: 22px; }
      .cols {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        gap: 16px;
      }
      ul { margin: 0; padding-left: 18px; }
      li { margin-bottom: 8px; color: #cbd5e1; }
      .flow {
        margin-top: 12px;
        padding: 12px 14px;
        border-radius: 12px;
        border: 1px dashed rgba(56, 189, 248, .4);
        background: rgba(15, 23, 42, .55);
        color: #bae6fd;
        font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
        font-size: 13px;
      }
      .footer {
        margin: 26px 0 34px;
        color: #93c5fd;
        font-size: 13px;
      }
      .ok {
        color: var(--ok);
        font-weight: 600;
      }
    </style>
  </head>
  <body>
    <main class="container">
      <section class="hero">
        <span class="tag">Platform Engineering</span>
        <h1><span class="brand">brainctl</span> • Infraestrutura como Produto</h1>
        <p class="lead">
          Este ambiente foi provisionado com brainctl para demonstrar um portfólio real de automação AWS com governança, observabilidade e recuperação de desastre.
          O objetivo é acelerar entrega de negócio com padrão operacional confiável.
        </p>

        <div class="grid">
          <article class="card">
            <h3>Provisionamento padronizado</h3>
            <p>Ambientes seguem contrato YAML com validações, reduzindo erros manuais e retrabalho.</p>
          </article>
          <article class="card">
            <h3>Escala e resiliência</h3>
            <p>ALB, Auto Scaling e monitoração contínua para manter disponibilidade da aplicação.</p>
          </article>
          <article class="card">
            <h3>Observabilidade orientada a ação</h3>
            <p>Dashboards, alarmes e Session Manager para diagnóstico rápido sem depender de RDP aberto.</p>
          </article>
          <article class="card">
            <h3>Recovery + DR Drill mensal</h3>
            <p>Snapshots, runbooks de restore e simulação recorrente de recuperação para validar prontidão.</p>
          </article>
        </div>
      </section>

      <section class="section">
        <h2>Resumo da arquitetura da solução</h2>
        <div class="cols">
          <div>
            <ul>
              <li><strong>CLI em Go:</strong> interpreta o contrato declarativo e aplica guardrails de segurança.</li>
              <li><strong>Gerador Terraform:</strong> constrói workspace e módulos AWS de forma consistente.</li>
              <li><strong>Blueprint ec2-app:</strong> app, db opcional, load balancer e autoscaling.</li>
              <li><strong>Observabilidade:</strong> métricas, alarmes e trilha de operação com CloudWatch/SNS.</li>
            </ul>
          </div>
          <div>
            <ul>
              <li><strong>Recovery:</strong> snapshots automáticos e runbooks para recuperação controlada.</li>
              <li><strong>DR Drill:</strong> agenda mensal com EventBridge Scheduler + SSM Automation.</li>
              <li><strong>Governança:</strong> arquivos YAML por SG para customização segura.</li>
              <li><strong>Status operacional:</strong> outputs claros para times técnicos e de produto.</li>
            </ul>
          </div>
        </div>
        <div class="flow">app.yaml (+security-groups/*.yaml) → validação (Go) → geração Terraform → AWS pronta para operação</div>
      </section>

      <p class="footer">
        <span class="ok">● ambiente ativo</span> | Portfolio brainctl | AWS + Terraform + Go
      </p>
    </main>
  </body>
</html>
'@

$ErrorActionPreference = "Stop"

# Log do bootstrap
$logPath = "C:\ProgramData\brainctl-iis-setup.log"
New-Item -ItemType Directory -Force -Path (Split-Path $logPath) | Out-Null
Start-Transcript -Path $logPath -Append

try {
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools | Out-Null

    $webRoot = "C:\inetpub\wwwroot"
    New-Item -ItemType Directory -Force -Path $webRoot | Out-Null

    # --- Correção 1: desfaz encoding quebrado (Ã§ / â€¢ / â†’ etc) ---
    $pageHtmlFixed = [System.Text.Encoding]::UTF8.GetString(
        [System.Text.Encoding]::GetEncoding(1252).GetBytes($pageHtml)
    )

    # Gravar index.html em UTF-8 sem BOM
    $indexPath = Join-Path $webRoot "index.html"
    [System.IO.File]::WriteAllText($indexPath, $pageHtmlFixed, (New-Object System.Text.UTF8Encoding($false)))

    # --- Correção 2: web.config com remoção de header duplicado + utf-8 ---
    $webConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <httpProtocol>
      <customHeaders>
        <remove name="Content-Type" />
        <add name="Content-Type" value="text/html; charset=utf-8" />
      </customHeaders>
    </httpProtocol>
  </system.webServer>
</configuration>
"@

    $webConfigPath = Join-Path $webRoot "web.config"
    [System.IO.File]::WriteAllText($webConfigPath, $webConfigContent, (New-Object System.Text.UTF8Encoding($false)))

    # (Opcional) garantir que o Default Web Site aponte para o webroot esperado
    Import-Module WebAdministration
    Set-ItemProperty "IIS:\Sites\Default Web Site" -Name physicalPath -Value $webRoot

    # Reinicia IIS de forma confiável
    iisreset | Out-Null

    # Validação simples sem depender do motor do IE
    $resp = Invoke-WebRequest "http://localhost/" -UseBasicParsing
    Add-Content -Path $logPath -Value ("StatusCode: " + $resp.StatusCode)
    Add-Content -Path $logPath -Value ("Content-Type: " + $resp.Headers["Content-Type"])
}
catch {
    Add-Content -Path $logPath -Value ("ERRO: " + $_.Exception.Message)
    throw
}
finally {
    Stop-Transcript | Out-Null
}
