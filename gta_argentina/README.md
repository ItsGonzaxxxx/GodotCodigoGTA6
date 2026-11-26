# GTA ARGENTINA (Godot 4.3+ / probado en 4.7.2)

## Cómo abrirlo
Importá la carpeta (project.godot) en Godot y presioná F5.

## Controles
WASD mover · Shift correr · C agacharse · Espacio saltar · E interactuar/hablar/subir/bajar/agarrar · R arrebatar · V liberar/capturar mouse · Esc pausa

## Estructura
- scripts/city_layout.gd   Constantes, zonas y grafos (peatonal y de tráfico)
- scripts/city_builder.gd  Calles, señalización, manzanas por zona, plaza, luminarias
- shaders/facade.gdshader  Fachadas con ventanas por piso y planta baja comercial
- scripts/pedestrian.gd    Peatón con rutina y diálogos; scripts/crowd.gd los genera
- scripts/traffic_car.gd   Auto IA (auto, taxi, colectivo); scripts/traffic.gd el gestor
- scripts/player.gd, interactable.gd, input_setup.gd, main.gd

## FASE 1 y 2 (completas): personaje, mapa 6x6 con 5 zonas, 70 peatones, tráfico IA.
## FASE 3 (completa): vehículos conducibles
- 6 tipos: auto, camioneta, colectivo, camión, moto, bicicleta (parámetros distintos de
  aceleración, frenado, agarre, giro, peso y cámara). Exhibición junto a la plaza (calle x=0) y 10 estacionados.
- Subir/bajar con E en la puerta del conductor. W/S acelerar/frenar/reversa, A/D girar, Espacio freno de mano
  (derrape), H bocina, Shift = pedaleo fuerte en bici. Cámara que sigue al vehículo, FOV según velocidad, temblor en choques.
- Física arcade (no VehicleBody3D): curva de motor, resistencia, giro limitado por agarre, deslizamiento lateral,
  cabeceo/balanceo de carrocería, ruedas que giran y doblan, luces de freno, faros (de noche).
- Colisiones con edificios/árboles/otros autos; daño visual: capó doblado, pintura sucia, humo, vehículo averiado
  (velocidad máxima reducida). Sonido: motor sintetizado con cambios de marcha, bocina, choque.
## Personaje: cuerpo articulado (cabeza, torso, brazos y piernas de 2 segmentos, manos, pies, pelo, accesorios)
con animación procedural: idle, caminar, correr, agacharse, saltar, manejar auto/moto, pedalear. Peatones lo usan.
## Realismo visual: ciclo día/noche (sol, luna, cielo, niebla, luminarias y ventanas encendidas), SSAO, bloom, ACES,
sombras en cascada, MSAA+FXAA, shaders procedurales (fachadas con ventanas/persianas/vidrieras/cornisas, asfalto, baldosas, pasto).

## FASE 4 (parcial): chorros, subtítulos y menús
- Chorros (ladrones ficticios, con pasamontañas): acechan al jugador a pie con plata, le roban una parte y huyen.
  Se los persigue y se los agarra con E para recuperar la plata; si escapan, se pierde. Se reponen solos.
- Arrebato del jugador (R): da plata, asusta a los civiles y los testigos/policía suben el nivel de búsqueda (★ 1–3).
  La policía (patrulla + refuerzos) persigue a pie; si te alcanzan te detienen (fianza ~20 %, vuelta a la plaza).
  La búsqueda baja al alejarte o con el tiempo.
- Subtítulos con nombre y color del que habla (cola), notificaciones laterales (+$ / -$, avisos) y carteles
  centrales (¡TE CHOREARON!, DETENIDO).
- Menú de inicio (ciudad de fondo en vivo), pausa con Esc (Continuar, Controles, Opciones, Menú principal, Salir),
  opciones persistentes (volumen, sensibilidad, distancia de dibujado, sombras, pantalla completa).
- V libera/captura el mouse (Esc ya no lo hace).

## Pruebas automáticas
`godot --headless --path . -- --smoke-ui`  (~1 min: subtítulos, menús, pausa, V, opciones, chorro, arrebato, arresto)
`godot --headless --path . -- --smoke`     (~3 min: animación, tráfico, cada vehículo, choque, kiosco, día/noche)

## Prueba automática (detalle anterior)
`godot --headless --path . -- --smoke`  (~3 min: animación, tráfico, cada vehículo, choque, kiosco, diálogo, día/noche)

## Limitaciones conocidas
- Todo es geometría procedural (sin modelos/texturas artísticas): el "realismo" real requiere assets 3D profesionales.
- No verificado visualmente (solo pruebas headless): ajustá cámara, colores y sensación de manejo al probarlo.
- Peatones sin colisión (se atraviesan) ni reacción a atropellos. Sin semáforos.
- Policía y chorros se mueven por las veredas (grafo) y en línea recta al acercarse: pueden cruzar objetos en distancias cortas.
- La policía sólo persigue a pie; en vehículo se la despista pero aún no hay patrulleros ni disparos (Fase 6).
- Sin guardado de partida todavía (Fase 7): el menú no muestra 'Continuar' para no ofrecer algo que no existe.
- Vehículos no se pueden robar a la IA ni subir con pasajeros; las motos no se caen al chocar.
