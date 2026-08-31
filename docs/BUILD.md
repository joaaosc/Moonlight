# Builds do Moonlight

## DerivedData isolado

O DerivedData canônico do Moonlight fica fora do repositório, em:

```text
/Users/joaocosta/Library/Developer/Xcode/DerivedData.noindex/Moonlight
```

O sufixo `.noindex` evita que os produtos de compilação sejam tratados como conteúdo de busca pelo Spotlight. Ele não altera a preferência global do Xcode nem afeta outros projetos. O conteúdo é regenerável e pode ser removido sem perder fontes, histórico ou configurações.

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

## Versão atual

- Marketing version: `0.1.0-pre-alpha.3`;
- build: `9`;
- deployment target: macOS `27.0`.
