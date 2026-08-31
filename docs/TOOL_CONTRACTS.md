# Contratos das ferramentas iniciais

Estado de referência: esquema de parâmetros 1, macOS 27 beta, Xcode 27 e Swift 6.4 em 2026-08-31.

Este documento fecha o gate P1 do roadmap. Ele descreve o comportamento do domínio; não publica novos App Intents e não promete como o Spotlight apresentará cada ferramenta.

## Envelope comum

Toda execução recebe um `ActionRequest` com:

- `actionID`: ID persistente da ferramenta;
- `input`: texto bruto, inclusive espaços e quebras de linha;
- `parameters.schemaVersion`: versão do envelope, atualmente `1`;
- `parameters.values`: mapa de strings convertido pelo handler para o tipo específico da ferramenta.

O `ActionRunner` rejeita versões diferentes de `1`. Sucessos e falhas persistem o texto bruto e os parâmetros usados. Registros históricos anteriores continuam válidos sem o campo `parameters`; nesse caso, o valor decodificado é `nil` e equivale semanticamente ao envelope vazio legado.

Regras comuns:

- entrada máxima: 262.144 bytes UTF-8 (256 KiB);
- saída máxima: 524.288 bytes UTF-8 (512 KiB);
- nenhuma ferramenta acessa rede, arquivo, clipboard, janela ou estado global;
- nenhuma ferramenta exige permissão do usuário;
- todas podem executar em background no processo principal ou numa App Intents Extension;
- nenhuma copia o resultado implicitamente;
- cancelamento é verificado antes e depois do trabalho relevante e não é persistido como falha funcional;
- erros não incluem o conteúdo fornecido pelo usuário;
- o domínio sempre persiste o resultado integral aceito; uma superfície pode exibir uma prévia identificada como tal, mas não pode apresentar truncamento como resultado completo.

## Matriz de contratos

| ID | Título | Parâmetros v1 | Entrada vazia | Normalização | Idempotente | Entrada pública inicial |
| --- | --- | --- | --- | --- | --- | --- |
| `clean-text` | Clean Text | nenhum | rejeitada após limpeza das bordas | NFC; espaços internos preservados | sim | não; catálogo/paleta primeiro |
| `format-json` | Format JSON | nenhum | rejeitada após limpeza das bordas | nenhuma dentro do JSON | sim | somente experimento S1 |
| `generate-uuid` | Generate UUID | nenhum | exigida; whitespace isolado equivale a vazio | ASCII minúsculo | não | não; catálogo/paleta primeiro |
| `base64-text` | Base64 | `operation=encode|decode` | aceita e produz vazio | UTF-8 exato; nenhuma limpeza | sim por operação | somente experimento S2 |

`isIdempotent` descreve o resultado do handler para o mesmo request. Ele não torna automaticamente seguro repetir efeitos de uma futura superfície.

## `clean-text`

Entrada: texto Unicode.

Algoritmo v1, nesta ordem:

1. rejeitar entrada acima de 256 KiB;
2. converter para Unicode NFC com `precomposedStringWithCanonicalMapping`;
3. remover somente caracteres de `whitespacesAndNewlines` nas bordas do texto completo;
4. rejeitar resultado vazio;
5. preservar literalmente espaços, tabs, newlines, emoji e grapheme clusters internos;
6. rejeitar saída acima de 512 KiB.

Não há correção ortográfica, alteração de caixa, colapso de espaços, troca de aspas, remoção de caracteres invisíveis internos nem normalização por linha. O detalhe da execução contém o texto limpo completo. Snippet e paleta podem mostrá-lo como texto copiável por ação explícita.

Erros: envelope com parâmetros inesperados, entrada vazia, entrada grande ou saída grande.

## `format-json`

Entrada: JSON UTF-8 estrito.

Algoritmo v1:

1. rejeitar entrada acima de 256 KiB;
2. usar `whitespacesAndNewlines` somente para detectar uma entrada vazia, sem modificar a entrada analisada;
3. rejeitar lexicalmente trailing comma fora de strings, porque o `JSONSerialization` do SDK de referência a aceita;
4. analisar os bytes brutos com `JSONSerialization` e `fragmentsAllowed` somente para distinguir um escalar válido de sintaxe inválida;
5. rejeitar imediatamente qualquer fragmento e aceitar apenas objeto ou array no nível superior;
6. rejeitar mais de 64 níveis de objetos/arrays aninhados;
7. serializar com `prettyPrinted` e `sortedKeys`;
8. não acrescentar newline terminal;
9. rejeitar saída acima de 512 KiB.

Nenhuma parte do JSON recebe NFC, trim ou qualquer outra transformação antes da análise. Escapes, números e Unicode seguem as regras de leitura e escrita do `JSONSerialization`. Fragmentos escalares, comentários, JSON5, trailing commas e JSON malformado não fazem parte do contrato.

O detalhe da execução contém o JSON completo. A paleta pode oferecer visualização e cópia explícita. Um snippet experimental deve mostrar resumo e prévia identificada quando o resultado não couber, mantendo o valor integral no histórico.

Erros: parâmetros inesperados, entrada vazia, JSON inválido, raiz não contêiner, profundidade acima de 64, entrada grande ou saída grande.

## `generate-uuid`

Entrada: nenhuma. Uma string composta somente por whitespace é tratada como ausência de entrada; qualquer outro texto é rejeitado.

O handler usa `UUID()` da Foundation, que gera UUID aleatório RFC 4122 versão 4, e apresenta `uuidString` em minúsculas no formato canônico de 36 caracteres com hífens. Não há seed, namespace ou variante de UUID selecionável no esquema 1. O gerador pode ser injetado somente para teste determinístico.

O resultado não deve ser descrito como segredo, senha ou token criptográfico. Snippet e paleta podem exibir o UUID completo e oferecer cópia explícita.

Erros: parâmetros inesperados, texto inesperado ou entrada grande. A ação não é idempotente porque duas execuções válidas normalmente produzem valores diferentes.

## `base64-text`

Entrada: texto e exatamente um parâmetro `operation`.

Valores permitidos:

- `encode`: converte os bytes UTF-8 exatos da entrada para Base64 padrão com padding;
- `decode`: exige Base64 padrão canônico e converte os bytes obtidos para uma string UTF-8 válida.

Não há trim, NFC, remoção de newline, tolerância de caracteres desconhecidos, alfabeto Base64URL nem fallback para dados binários. Na decodificação, o dado aceito precisa recodificar exatamente para a entrada; assim, whitespace, padding ausente e representações alternativas são rejeitados. A string vazia é válida nas duas operações e produz string vazia.

O detalhe contém o resultado completo. A paleta pode oferecer cópia explícita. Um snippet experimental deve preservar a distinção entre operação, erro de Base64 e erro de UTF-8.

Erros: versão de esquema incompatível, parâmetro ausente, operação desconhecida, parâmetro adicional, Base64 não canônico, bytes decodificados que não formam UTF-8, entrada grande ou saída grande.

## Política de superfícies

P1 e P2 não registram essas ferramentas no Spotlight. Os handlers entram somente no catálogo interno.

- `Format JSON` é o candidato isolado do experimento S1 por exercitar texto obrigatório, falha e saída multilinha.
- `Base64` é o candidato isolado do experimento S2 por exercitar parâmetro enumerado.
- `Clean Text` e `Generate UUID` começam na futura paleta para evitar aumentar resultados antes de medir descoberta e usabilidade.
- qualquer execução via App Intent deve continuar em background; nenhuma dessas quatro ferramentas justifica `continueInForeground()`.
- promoção permanente depende de teste físico do Spotlight com o app aberto e encerrado, separado de build, metadata e testes hospedados.

## Fora do esquema 1

- arquivos ou conteúdo binário;
- Base64URL e variantes MIME;
- JSON5, reparo automático ou preservação da ordem original das chaves;
- UUID v1, v3, v5, v6, v7 ou namespaces;
- limpeza linguística, Markdown, HTML ou texto por heurística;
- cópia automática, rede, shell, plugins ou IA.
