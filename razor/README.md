# Efeitos Razer 🔥

Esta pasta contém efeitos de iluminação personalizados para periféricos Razer, preparados em formato JSON para utilização com o [Polychromatic](https://polychromatic.app/).

## Efeitos disponíveis

| Ficheiro | Dispositivo | Matriz | Frames | Velocidade |
|---|---|---:|---:|---:|
| [FireOrnataChromav3.json](./FireOrnataChromav3.json) | Razer Ornata Chroma | 22 × 6 | 30 | 10 FPS |
| [FireBasiliskV3.json](./FireBasiliskV3.json) | Razer Basilisk V3 | 11 × 1 | 30 | 10 FPS |

Ambos os efeitos usam uma paleta de tons vermelhos, laranja e amarelos, com animação em ciclo contínuo.

## Instalação

1. Confirma que o dispositivo é reconhecido pelo OpenRazer e pelo Polychromatic.
2. Copia o ficheiro JSON correspondente ao dispositivo para a pasta de efeitos personalizados do Polychromatic:

   ```bash
   mkdir -p ~/.config/polychromatic/effects
   cp FireOrnataChromav3.json ~/.config/polychromatic/effects/
   ```

   Para o rato, substitui o nome do ficheiro pelo `FireBasiliskV3.json`.

3. Abre ou reinicia o Polychromatic e seleciona o efeito na lista de efeitos personalizados.

## Compatibilidade e formato

- Efeitos preparados com a estrutura de sequência JSON utilizada pelo Polychromatic 0.9.8.
- A matriz de cada ficheiro corresponde ao mapeamento do respetivo dispositivo nessa versão do Polychromatic.
- A reprodução depende do suporte do dispositivo e do serviço OpenRazer instalado no sistema.
- Os ficheiros definem 30 frames, 10 FPS e repetição contínua (`loop: true`).

## Notas

Os efeitos são configurações personalizadas; não são perfis oficiais da Razer nem ficheiros exportados do Razer Synapse. A aparência e a reprodução podem variar consoante a versão do Polychromatic, do OpenRazer e o hardware.
