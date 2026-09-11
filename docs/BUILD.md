# Builds do Moonlight

## DerivedData isolado

O DerivedData do Moonlight fica em `build.noindex/DerivedData`, dentro do repositório e ignorado pelo Git. É o caminho que `Scripts/release.sh` usa.

O sufixo `.noindex` reduz a indexação de produtos de compilação pelo Spotlight, mas não impede registros no Launch Services/PlugInKit criados por builds ou testes. O conteúdo é regenerável e pode ser removido sem perder fontes, histórico ou configurações.

O Xcode aberto pela interface não passa a usar esse caminho automaticamente. Para builds reproduzíveis, informar explicitamente:

```text
xcodebuild \
  -project MoonlightTools.xcodeproj \
  -scheme Moonlight \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build.noindex/DerivedData \
  build
```

Não configurar `DerivedDataLocation` global nem executar limpeza ampla do índice Spotlight como parte do build.

## Ciclo de desenvolvimento e cópia instalada

App Intents, widgets e as superfícies Spotlight leem o bundle registrado no Launch Services, e este projeto mantém exatamente uma cópia registrada, em `/Applications`. Uma mudança só é observável depois de instalada ali.

`Scripts/release.sh` não serve para esse ciclo: ele arquiva em Release com otimização de módulo inteiro e exporta com Developer ID, o que existe para notarização. O ciclo é `Scripts/dev-install.sh`:

```text
bash Scripts/dev-install.sh
```

Compila Debug no DerivedData do repositório, encerra a cópia em execução, substitui `/Applications/Moonlight.app`, verifica a assinatura, registra o bundle e desregistra as demais cópias. Assinatura, entitlements, sandbox e hardened runtime são os mesmos do Release, então o que o sistema enxerga é equivalente para validação. O projeto só é regenerado quando `project.yml` estiver mais novo que o `.xcodeproj`, para não reescrever o arquivo sob um Xcode aberto.

### Instalação automática a partir do Xcode

Um build iniciado pela interface do Xcode carimba o número correto sozinho: o scheme `Moonlight` tem uma pre-action de build, declarada em `project.yml`, que executa `Scripts/version.sh` antes de o target resolver os xcconfigs. Uma build phase seria tarde demais, porque os xcconfigs já teriam sido lidos.

Falta instalar, e isso é o que a tela `Xcode > Settings > Behaviors` resolve:

- em **When build succeeds**, marcar *Run script* e apontar para `Scripts/install-after-build.sh`;
- em **When build starts**, nada. Behaviors são configuração global do usuário, não acompanham o repositório e rodam fora do ambiente do build, sem `CONFIGURATION` nem `TARGET_BUILD_DIR`. Um script ali roda antes de o produto existir e instalaria o bundle anterior.

A tela aceita apenas o caminho de um script, sem argumentos, e por isso existe `Scripts/install-after-build.sh`: ele é o ponto de entrada sem parâmetros que chama `dev-install.sh --skip-build`.

O wrapper também decide se vale instalar. O Behavior dispara em todo build bem-sucedido, inclusive builds de teste, e instalar significa encerrar a cópia em execução; quando `status.sh` diz que a cópia instalada já está em dia, ele não faz nada. Como a saída de um Behavior não aparece em lugar nenhum, o resultado vai para o log do sistema:

```sh
log show --last 10m --info --predicate 'process == "logger"' | grep moonlight-install
```

`--skip-build` instala um produto já compilado em vez de compilar de novo. Ele escolhe o bundle construído mais recentemente entre o DerivedData do repositório e o DerivedData global que a interface do Xcode usa, porque o build pode ter vindo de qualquer um dos dois.

`MARKETING_VERSION` continua manual, em `Config/Version.xcconfig`: muda por decisão, não por build.

`Scripts/status.sh` responde se a cópia instalada corresponde ao checkout, e sai com código diferente de zero quando não corresponde, de modo a poder condicionar uma validação de runtime:

```text
bash Scripts/status.sh
```

São duas verificações independentes, porque falham por motivos diferentes:

- `CFBundleVersion` instalado contra `git rev-list --count HEAD`, que mede defasagem em commits;
- data do executável instalado contra a fonte mais recente em `App/`, `Packages/`, `Config/` e `project.yml`, que detecta edições ainda não instaladas, commitadas ou não.

O comando também lista as cópias registradas no Launch Services. Mais de uma entrada é a causa das entradas duplicadas do Moonlight no Spotlight; `Scripts/clean-app-registrations.sh` remove as excedentes e `dev-install.sh` já o executa.

Build verde não substitui esse gate: o Xcode registra cada produto que escreve, inclusive em DerivedData globais de checkouts antigos, e essas cópias competem com a instalada.

## Número de build

O build não está no controle de versão. Ele era `CURRENT_PROJECT_VERSION` em `project.yml`, o que transformava cada build em um commit e impedia que duas branches o incrementassem sem colidir.

A versão agora vem de `Config/Version.xcconfig`:

- `MARKETING_VERSION` é versionado, porque muda por decisão e não por build;
- `CURRENT_PROJECT_VERSION` vale `1` no arquivo versionado, apenas como piso;
- `Config/Version.generated.xcconfig` sobrescreve esse piso e é ignorado pelo Git.

O arquivo gerado é escrito por `Scripts/version.sh`:

```text
bash Scripts/version.sh
```

- localmente o número é `git rev-list --count HEAD`, monotônico e sem diff;
- no Xcode Cloud é `CI_BUILD_NUMBER`, escrito por `ci_scripts/ci_post_clone.sh`.

`Scripts/release.sh` chama o script antes de gerar o projeto, então uma release local não exige nenhuma edição de arquivo versionado.

Os dois espaços não colidem: o Xcode Cloud está configurado para começar em `1000` e o contador local acompanha a contagem de commits. Um checkout sem o arquivo gerado ainda compila, com build `1`.

## Versão atual

- Marketing version: `2.0.1`;
- build local: derivado da contagem de commits;
- build do Xcode Cloud: atribuído pelo serviço a partir de `1000`;
- deployment target: macOS `27.0`.

## Xcode Cloud

O produto já existe em `MoonlightTools.xcodeproj/xcshareddata/xcodecloud/manifest.json`.

`ci_scripts/ci_post_clone.sh` roda depois do clone e faz duas coisas: escreve o build number a partir de `CI_BUILD_NUMBER` e regenera o projeto a partir de `project.yml` com XcodeGen instalado por Homebrew. Se o XcodeGen não instalar, o build segue com o projeto versionado e registra o aviso no log.

O workflow de validação deve executar build e testes, sem arquivar nem distribuir: uma validação de branch não deve produzir versão no App Store Connect.

### Bloqueio atual: o Xcode Cloud não alcança o toolchain do projeto

Nenhum workflow foi criado, porque um workflow criado hoje falharia em todo build.

- O projeto exige `MACOSX_DEPLOYMENT_TARGET` `27.0` em todos os targets, `.macOS("27.0")` em `Package.swift` e compila contra `MacOSX27.0.sdk`.
- As notas de versão do Xcode Cloud não anunciam Xcode 27 nem macOS 27. A entrada mais recente de ambiente é Xcode 26.2 (17C52) com macOS Tahoe 26.2 (25C56), de 19 de dezembro de 2025.
- Um SDK não aceita deployment target acima da própria versão, então Xcode 26.2 não compila este projeto.

O repositório já está pronto para quando o ambiente existir: `ci_scripts/ci_post_clone.sh` e o versionamento derivado não dependem de nada além do serviço oferecer o Xcode correto. O que falta é um passo de interface:

1. No Xcode, `Integrate > Xcode Cloud > Create Workflow…`, ou a aba Xcode Cloud do app no App Store Connect.
2. Environment com a versão de Xcode que suporte macOS 27, quando disponível.
3. Ações: apenas Build e Test. Nenhum Archive, nenhum Distribute.
4. Start condition em mudança de branch em `main`, a única branch do repositório.
5. Em `Settings > Build Number`, definir o próximo build number como `1000`, mantendo o espaço do serviço separado do contador local.

Observações registradas para esse momento:

- a Apple documenta que `brew install` quebra em imagens de macOS pré-lançamento no Xcode Cloud; por isso o post-clone trata a instalação do XcodeGen como opcional e segue com o projeto versionado;
- o scheme `Moonlight` inclui `MoonlightAppIntentsUITests`, que depende de registro de App Intents no sistema. O comportamento dessa suíte em ambiente efêmero é desconhecido; se ela for instável no serviço, use um test plan restrito a `MoonlightTests`.

### O Xcode Cloud não substitui o gate físico

O serviço compila e testa na nuvem e distribui por TestFlight ou App Store. Ele não instala nada em `/Applications` desta máquina. A validação de Spotlight das superfícies `omt`, `omc` e `omw` continua exigindo um bundle assinado rodando localmente.

O que mudou é o custo dessa validação: com o build number fora do controle de versão, rodar `Scripts/release.sh` e instalar não altera nenhum arquivo versionado e não produz commit.
