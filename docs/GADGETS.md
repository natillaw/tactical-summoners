# Gadgets — objetos de utilidad (diseño)

Los gadgets van en los slots **3 y 4** (teclas 3 y 4), con cooldown propio y cargas limitadas (se recargan en el pueblo).
Los fabrican los oficios de Cimiento o los sueltan Ecos especiales. Aquí solo el diseño; **aún no están implementados**.

| Gadget | Qué hace | Oficio / origen | Desde |
|---|---|---|---|
| **Garfio con cuerda** | Lanzas un gancho en línea: si acierta a un enemigo, lo arrastra hasta ti (3 s de aturdimiento si es un esbirro); si acierta a un obstáculo, te impulsa hacia él. | Herrero (gancho) + Peletero (cuerda) | piso 2 |
| **Bomba de pólvora negra** | Esfera lanzable: explosión de área y empuje. | Herrero | piso 3 |
| **Trampa de pinchos** | Se coloca en el suelo; el primero que la pisa queda atado 2 s y sangra. | Carpintero | piso 2 |
| **Ballesta de mano** | Un disparo perforante de gran daño, recarga lenta. | Carpintero + Herrero | piso 6 |
| **Escudo plegable** | Despliega un escudo portátil 4 s que bloquea proyectiles de frente. | Carpintero + Peletero | piso 4 |
| **Frasco de fuego** | Lanza un frasco: charco de fuego 5 s. | Alquimista | piso 2 |
| **Frasco de escarcha** | Charco que ralentiza un 50 % durante 5 s. | Alquimista | piso 4 |
| **Frasco de veneno** | Nube que apila veneno (hasta 3 cargas). | Alquimista | piso 3 |
| **Humo cegador** | Nube: los enemigos dentro pierden el objetivo 3 s. Permite escapar o flanquear. | Alquimista + Sastre | piso 5 |
| **Elixir de salto (frasco)** | Impulso instantáneo de 6 m en la dirección del movimiento. | Alquimista | piso 6 |
| **Capa de sombras** | 4 s de sigilo: los enemigos no te ven si no atacas. | Sastre | piso 5 |
| **Red de captura** | Lanzas una red: ata a un enemigo 2.5 s (los élites la rompen en 1 s). | Sastre + Carpintero | piso 3 |
| **Látigo** | Atrae a un enemigo hasta media distancia y lo marca. | Peletero | piso 4 |
| **Bolsa extra** | +6 huecos de mochila (pasivo, no usa slot). | Peletero | piso 3 |
| **Odre de viaje** | Beber 3 cargas de curación del 15 % durante 6 s; se rellena en el pueblo. | Peletero + Alquimista | piso 2 |
| **Silbato del Eco** | Atrae a los enemigos cercanos a un punto marcado durante 5 s. | Drop: Eco de Héroe (pícaro) | piso 7 |
| **Fragmento de Coloso** | Onda sísmica: aturde en área, un solo uso por piso. | Drop: Colosos (piso 5 y 10) | piso 5 |
| **Lente del Pliegue** | Revela cofres, nodos y salas ocultas del piso 20 s. | Drop: Eco de Héroe (mago) | piso 8 |

## Reglas de diseño

- Un gadget **nunca** sustituye a una skill de clase: añade utilidad (movimiento, control, información), no daño sostenido.
- Cargas limitadas por piso (2–3); rellenar cuesta materiales en el pueblo. Evita que dominen el combate.
- Los drops de Ecos especiales son únicos por piso y no se pueden fabricar.
- Cada gadget necesita VFX, sonido y un icono propio antes de implementarse.
