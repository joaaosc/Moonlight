# Moonlight

Moonlight é um conjunto de ações rápidas para o macOS, acessíveis pelo Spotlight e Shortcuts integrado ao framework App Intents com o SDK beta da Apple para o macOS 27 Golden Gate.

Por enquanto é um teste de levar as capacidades do Spotlight/Siri ao limite e juntar com a suíte de mudanças interessantes para powerusers/devs do framework App Intents. Caso o teste seja bem-sucedido, existe a possibilidade de port para iOS 27.

## Estrutura

- `App/` — o app, a extensão de App Intents e os widgets;
- `Packages/MoonlightKit/` — domínio, infraestrutura, intents e UI, independentes do projeto Xcode;
- `Scripts/` e `ci_scripts/` — geração do projeto, número de build e release;
- `project.yml` — fonte do `MoonlightTools.xcodeproj`, regenerado com XcodeGen.

## Build

```sh
xcodegen generate
xcodebuild -project MoonlightTools.xcodeproj -scheme Moonlight -destination 'platform=macOS' build
```

Os testes do pacote rodam com `swift test` em `Packages/MoonlightKit`.

## Licença

PolyForm Noncommercial License 1.0.0. Consulte [LICENSE.md](LICENSE.md).

## Release

Alpha `2.0.1`.

O número de build não é versionado: builds locais numeram-se pela contagem de commits e o Xcode Cloud atribui os seus. Consulte [docs/BUILD.md](docs/BUILD.md).
