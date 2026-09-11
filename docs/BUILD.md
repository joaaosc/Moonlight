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
