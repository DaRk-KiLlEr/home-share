# Efeitos Razer 🔥

Esta pasta contém efeitos de iluminação personalizados para periféricos Razer, preparados em formato JSON para utilização com o [Polychromatic](https://polychromatic.app/).

## Efeitos disponíveis

| Ficheiro | Dispositivo | Estilo | Matriz | Frames | Velocidade |
|---|---|---|---:|---:|---:|
| [FireOrnataChromav3.json](./FireOrnataChromav3.json) | Razer Ornata Chroma | Fogo clássico | 22 × 6 | 15 | 10 FPS |
| [FireOrnataChromav4.json](./FireOrnataChromav4.json) | Razer Ornata Chroma | Fogo com maior presença de vermelho e tons quentes | 22 × 6 | 15 | 15 FPS |
| [FireOrnataChromav5.json](./FireOrnataChromav5.json) | Razer Ornata Chroma | Fogo dominado por vermelho e carmesim | 22 × 6 | 15 | 15 FPS |
| [FireBasiliskV3.json](./FireBasiliskV3.json) | Razer Basilisk V3 | Fogo clássico | 11 × 1 | 15 | 10 FPS |

Todos os efeitos usam 15 frames e repetição contínua. As versões v3, v4 e v5 do Ornata Chroma são estilos independentes e podem coexistir na lista de efeitos personalizados.

## Instalação

1. Confirma que o dispositivo é reconhecido pelo OpenRazer e pelo Polychromatic.
2. Copia o ficheiro JSON pretendido para a pasta de efeitos personalizados do Polychromatic:

   ```bash
   mkdir -p ~/.config/polychromatic/effects
   cp FireOrnataChromav4.json ~/.config/polychromatic/effects/
   ```

   Altera o nome do ficheiro no comando para instalar outro efeito.

3. Abre ou reinicia o Polychromatic e seleciona o efeito na lista de efeitos personalizados.

## Compatibilidade e formato

- Efeitos preparados com a estrutura de sequência JSON utilizada pelo Polychromatic 0.9.8.
- A matriz de cada ficheiro corresponde ao mapeamento do respetivo dispositivo nessa versão do Polychromatic.
- A reprodução depende do suporte do dispositivo e do serviço OpenRazer instalado no sistema.
- Todos os ficheiros incluem 15 frames e repetição contínua (`loop: true`); a velocidade de reprodução é indicada na tabela.

## Notas

Os efeitos são configurações personalizadas; não são perfis oficiais da Razer nem ficheiros exportados do Razer Synapse. A aparência e a reprodução podem variar consoante a versão do Polychromatic, do OpenRazer e o hardware.
