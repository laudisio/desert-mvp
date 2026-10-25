# Deserto MVP

Protótipo jogável em Godot 4.4: personagem placeholder, câmera em 3ª pessoa, sedan e trailer (RV) dirigíveis e um bairro suburbano no deserto. Sem missões.

## Controles
- WASD / setas: andar / dirigir
- Mouse: câmera, roda: zoom
- Shift: correr; Espaço: pular / freio de mão
- E: entrar / sair do veículo; R: desvirar veículo
- F11: tela cheia; Esc / P: pausa; H: esconder ajuda

## Rodar pelo código
1. Instale o Godot 4.4.1 (https://godotengine.org/download).
2. Abra o `project.godot` e aperte F5.

## Exportar
`godot --headless --path . --export-release "Windows Desktop" build/windows/DesertoMVP.exe`

## Smoke test
`godot --path . -- --autotest --shots=DIR` (salva screenshots e imprime verificações).
