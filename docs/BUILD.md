# Builds do Moonlight

## DerivedData isolado

O DerivedData canônico do Moonlight fica fora do repositório, em:

```text
/Users/joaocosta/Library/Developer/Xcode/DerivedData.noindex/Moonlight
```

O sufixo `.noindex` reduz a indexação de produtos de compilação pelo Spotlight, mas não impede registros no Launch Services/PlugInKit criados por builds ou testes. Ele não altera a preferência global do Xcode nem afeta outros projetos. O conteúdo é regenerável e pode ser removido sem perder fontes, histórico ou configurações.

O Xcode aberto pela interface não passa a usar esse caminho automaticamente. Para builds reproduzíveis, informar explicitamente:

```text
xcodebuild \
  -project Moonlight.xcodeproj \
  -scheme Moonlight \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /Users/joaocosta/Library/Developer/Xcode/DerivedData.noindex/Moonlight \
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

Os dois espaços não colidem: o Xcode Cloud está configurado para começar em `1000` e o contador local está em `67`. Um checkout sem o arquivo gerado ainda compila, com build `1`.

## Versão atual

- Marketing version: `0.1.0-pre-alpha.3`;
- build local: derivado da contagem de commits;
- build do Xcode Cloud: atribuído pelo serviço a partir de `1000`;
- deployment target: macOS `27.0`.

## Xcode Cloud

O produto já existe em `Moonlight.xcodeproj/xcshareddata/xcodecloud/manifest.json`.

`ci_scripts/ci_post_clone.sh` roda depois do clone e faz duas coisas: escreve o build number a partir de `CI_BUILD_NUMBER` e regenera o projeto a partir de `project.yml` com XcodeGen instalado por Homebrew. Se o XcodeGen não instalar, o build segue com o `Moonlight.xcodeproj` versionado e registra o aviso no log.

O workflow de validação executa build e testes e não arquiva nem distribui. Uma branch experimental não deve produzir versão no App Store Connect.
