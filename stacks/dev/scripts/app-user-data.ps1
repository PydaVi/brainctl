$pageHtml = @'
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>brainctl | Platform Engineering & Cloud Security</title>

  <style>
    :root{
      --bg:#050816;
      --card:#0f172acc;
      --line:#334155;
      --text:#e2e8f0;
      --muted:#94a3b8;
      --accent:#38bdf8;
      --accent2:#818cf8;
      --ok:#22c55e;
    }
    *{ box-sizing:border-box; }
    html,body{ margin:0; }
    body{
      font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
      color:var(--text);
      background:
        radial-gradient(circle at 15% 20%, #1e293b 0%, transparent 45%),
        radial-gradient(circle at 80% 10%, #1d4ed8 0%, transparent 35%),
        linear-gradient(160deg,#020617 0%,#060d1f 70%);
    }
    .container{ width:min(1100px,92vw); margin:0 auto; }
    .hero{ padding:80px 0 40px; }
    .tag{
      display:inline-block; padding:8px 16px; border-radius:999px;
      border:1px solid #334155; font-size:12px; letter-spacing:.1em; text-transform:uppercase;
      background: rgba(15,23,42,.55); color:#cbd5e1;
    }
    h1{
      font-size:clamp(36px,6vw,68px);
      line-height:1.05; margin:20px 0;
      letter-spacing:-0.03em;
    }
    .brand{
      background:linear-gradient(90deg,var(--accent2),var(--accent));
      -webkit-background-clip:text; background-clip:text; color:transparent;
    }
    .lead{
      max-width:850px; color:var(--muted);
      font-size:20px; line-height:1.6; margin:0;
    }

    .section{ margin-top:56px; }
    .section-head h2{
      margin:0 0 10px; font-size:26px; letter-spacing:-0.02em;
    }
    .section-head .sub{
      margin:0; max-width:860px; color:var(--muted); font-size:16px; line-height:1.65;
    }

    .cards{
      display:grid; grid-template-columns:repeat(auto-fit,minmax(250px,1fr));
      gap:20px; margin-top:25px;
    }
    .card{
      background: linear-gradient(180deg, rgba(15,23,42,.72), rgba(15,23,42,.52));
      border:1px solid rgba(148,163,184,.22);
      border-radius:18px; padding:22px; backdrop-filter:blur(8px);
    }
    .card h3{ margin:0 0 10px; font-size:16px; }
    .card p{ margin:0; color:var(--muted); line-height:1.55; font-size:14px; }

    .metric{ font-size:30px; font-weight:800; color:var(--accent); letter-spacing:-0.02em; }
    .flow{
      margin-top:20px; padding:14px; border:1px dashed rgba(56,189,248,.4); border-radius:12px;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      color:#bae6fd; background: rgba(2,6,23,.35);
    }

    /* features */
    .features{
      margin-top:22px;
      display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr));
      gap:18px;
    }
    .feature{
      position:relative;
      border-radius:18px; padding:18px;
      border:1px solid rgba(148,163,184,.22);
      background: linear-gradient(180deg, rgba(15,23,42,.72), rgba(15,23,42,.52));
      backdrop-filter: blur(8px);
      overflow:hidden;
    }
    .feature::before{
      content:"";
      position:absolute; inset:-60px -60px auto auto;
      width:180px; height:180px;
      background: radial-gradient(circle at 40% 40%, rgba(56,189,248,.18), transparent 60%);
      transform: rotate(18deg);
    }
    .icon{
      width:42px; height:42px; display:grid; place-items:center;
      border-radius:14px;
      border:1px solid rgba(129,140,248,.35);
      background: rgba(79,70,229,.12);
      font-size:18px;
    }
    .pill{
      display:inline-block; margin-top:12px; padding:6px 10px;
      border-radius:999px; border:1px solid rgba(56,189,248,.28);
      background: rgba(2,6,23,.35);
      color:#bae6fd;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size:12px;
    }
    .feature h3{ margin:10px 0 8px; font-size:16px; }
    .feature p{ margin:0; color:var(--muted); line-height:1.55; font-size:14px; }

    /* how it works */
    .how{
      margin-top:18px;
      display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr));
      gap:14px;
    }
    .step{
      display:grid; grid-template-columns:44px 1fr; gap:12px;
      padding:16px; border-radius:18px;
      border:1px solid rgba(148,163,184,.18);
      background: rgba(15,23,42,.55);
    }
    .num{
      width:38px; height:38px; border-radius:12px;
      display:grid; place-items:center;
      font-weight:800; color:#e0f2fe;
      background: linear-gradient(135deg, rgba(129,140,248,.35), rgba(56,189,248,.22));
      border:1px solid rgba(129,140,248,.35);
    }
    .step h3{ margin:0 0 6px; font-size:15px; }
    .step p{ margin:0; color:var(--muted); line-height:1.55; font-size:14px; }

    .footer{
      margin:50px 0 40px; font-size:13px; color:#93c5fd;
    }
  </style>
</head>

<body>
<main class="container">

  <section class="hero">
    <span class="tag">Platform Engineering • Cloud Security</span>

    <h1><span class="brand">brainctl</span><br/>Infraestrutura como Produto para Ambientes AWS</h1>

    <p class="lead">
      brainctl transforma infraestrutura em um contrato: padrões, guardrails e automações operacionais
      (observabilidade + recovery) são aplicados por padrão para reduzir drift e acelerar entregas.
    </p>
  </section>

  <section class="section">
    <h2>Impacto Real de Engenharia</h2>
    <div class="cards">
      <div class="card"><div class="metric">70%+</div><p>Meta/expectativa de redução de tempo entre “pedido” e ambiente operável.</p></div>
      <div class="card"><div class="metric">Menos drift</div><p>Padronização declarativa reduz configurações manuais inconsistentes.</p></div>
      <div class="card"><div class="metric">DR ready</div><p>Snapshots + runbooks + simulações recorrentes de recuperação.</p></div>
      <div class="card"><div class="metric">Security-first</div><p>Guardrails de governança aplicados automaticamente em todos workloads.</p></div>
    </div>
  </section>

  <section class="section">
    <h2>Principais recursos</h2>
    <div class="features">
      <article class="feature">
        <div class="icon">🧾</div>
        <h3>Contrato YAML + validações</h3>
        <p>Times descrevem o que precisam; o brainctl valida combinações e aplica guardrails antes de gerar Terraform.</p>
        <div class="pill">app.yaml + overrides</div>
      </article>

      <article class="feature">
        <div class="icon">🧩</div>
        <h3>Blueprint ec2-app</h3>
        <p>Template para workloads legados: APP com DB opcional, rede, segurança e outputs operacionais.</p>
        <div class="pill">workload: ec2-app</div>
      </article>

      <article class="feature">
        <div class="icon">⚖️</div>
        <h3>ALB + Auto Scaling (multi-AZ)</h3>
        <p>Camada de aplicação com ASG e balanceamento pronta para escala e substituição automática.</p>
        <div class="pill">health checks</div>
      </article>

      <article class="feature">
        <div class="icon">📈</div>
        <h3>Observabilidade orientada à ação</h3>
        <p>Dashboards e alarmes CloudWatch gerados automaticamente, com alertas via SNS.</p>
        <div class="pill">dashboards + alarms</div>
      </article>

      <article class="feature">
        <div class="icon">🔐</div>
        <h3>Operação sem RDP aberto</h3>
        <p>Suporte a Session Manager e endpoints privados de SSM para reduzir exposição e facilitar operação.</p>
        <div class="pill">SSM Session Manager</div>
      </article>

      <article class="feature">
        <div class="icon">🧯</div>
        <h3>Recovery automatizado</h3>
        <p>Snapshots diários via DLM e runbooks para recuperação controlada, incluindo restore completo da APP.</p>
        <div class="pill">DLM + SSM Automation</div>
      </article>

      <article class="feature">
        <div class="icon">🗓️</div>
        <h3>DR Drill mensal</h3>
        <p>Simulação recorrente de recuperação via EventBridge Scheduler para validar prontidão de verdade.</p>
        <div class="pill">EventBridge + SSM</div>
      </article>

      <article class="feature">
        <div class="icon">🛡️</div>
        <h3>Overrides por whitelist</h3>
        <p>Customizações controladas (ex: regras extras de SG) sem abrir margem para drift perigoso.</p>
        <div class="pill">whitelist paths</div>
      </article>
    </div>
  </section>

  <section class="section" aria-label="Como funciona">
    <div class="section-head">
      <h2>Como funciona</h2>
      <p class="sub">Do contrato declarativo ao ambiente operável, com previsibilidade e trilha de mudanças.</p>
    </div>

    <div class="how">
      <div class="step"><div class="num">1</div><div><h3>Defina o contrato</h3><p>Escreva <strong>app.yaml</strong> e, opcionalmente, <strong>overrides.yaml</strong>.</p></div></div>
      <div class="step"><div class="num">2</div><div><h3>Validação + guardrails</h3><p>Bloqueia combinações que “sobem”, mas quebram em produção.</p></div></div>
      <div class="step"><div class="num">3</div><div><h3>Geração Terraform</h3><p>Workspace e módulos consistentes com outputs para operação.</p></div></div>
      <div class="step"><div class="num">4</div><div><h3>AWS pronta para operar</h3><p>Provisionamento + observabilidade + recovery, já no padrão.</p></div></div>
    </div>

    <div class="flow">app.yaml (+overrides) → validação (Go) → geração Terraform → aplicação na AWS → operação padronizada</div>
  </section>

  <p class="footer">
    <span style="color:#22c55e">● ambiente ativo</span> | AWS • Terraform • Go • Cloud Security • Platform Engineering
  </p>

</main>
</body>
</html>
'@

$ErrorActionPreference = "Stop"
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
New-Item -ItemType Directory -Force -Path "C:\inetpub\wwwroot" | Out-Null
Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value $pageHtml -Encoding UTF8
Restart-Service W3SVC
