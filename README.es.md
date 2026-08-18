# SalaryTicker

<!-- language-bar -->
[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Español** · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Bahasa Melayu](README.ms.md)
<!-- language-bar -->

Una app de la barra de menús de macOS que muestra lo que llevas ganado hoy, avanzando segundo a segundo.

<img src="docs/panel.png" width="360" alt="El panel: lo ganado hoy, las tarifas que hay detrás, el acumulado del mes y dos objetivos de ahorro con las fechas en que quedarán pagados.">

Vive en la barra de menús como un número y un pequeño anillo de progreso. Haz clic para ver el detalle del día, el mes hasta ahora y lo cerca que estás de aquello para lo que ahorras.

- **Avanza segundo a segundo** contra tu horario real: horas, almuerzo no remunerado, días laborables.
- **Sabe de días libres.** Los festivos, el permiso pagado y el permiso sin sueldo caen en sitios distintos, y el permiso sin sueldo solo toca el salario base, no los complementos.
- **Pone precio a las cosas en trabajo.** Un objetivo se muestra en días de trabajo y en la fecha en que el horario dice que quedará pagado, no solo en dinero.
- **Nueve idiomas**, cualquier símbolo de moneda, cualquier zona horaria IANA.
- **Sin cuenta, sin red, sin telemetría.** Todo se calcula en tu Mac a partir de los ajustes que tú escribiste.

## Instalación

Requiere **macOS 26 o posterior** y una cadena de herramientas de Swift 6. Compilada y probada con Swift 6.3; las versiones anteriores de Swift 6 no están probadas.

```bash
git clone https://github.com/EnRui11/SalaryTicker.git
cd SalaryTicker
./Packaging/build_app.sh install
```

Eso compila un binario de release, genera el icono de la app desde el código fuente, ensambla `SalaryTicker.app`, lo firma ad hoc, lo copia en `/Applications` y lo abre. Quita el argumento `install` para compilar en el directorio de trabajo sin instalar.

No hay nada que sacar de cuarentena: el binario lo compilaste tú, así que nunca lleva la marca de descarga que busca Gatekeeper. La firma es ad hoc, suficiente para una app compilada en local, y le da al ítem de inicio una identidad estable.

Para actualizar, haz pull y ejecuta el mismo comando — reemplaza la copia instalada y la vuelve a abrir. Tus ajustes viven fuera del bundle y no se tocan.

Para desinstalar: sal desde el panel, borra `/Applications/SalaryTicker.app` y, si quieres que los ajustes también desaparezcan, `defaults delete com.steve.salaryticker`.

## Primer arranque

La barra de menús muestra `Configurar sueldo` hasta que el horario cuadre. Abre **Ajustes** desde el panel y rellena tres cosas:

1. **Pestaña Sueldo** — tu salario base y cualquier complemento fijo que lo acompañe.
2. **Pestaña Horario** — la entrada, la salida y el almuerzo no remunerado.
3. **Pestaña Sueldo, Días laborables** — qué días de la semana trabajas y cuáles de ellos son medios días.

<img src="docs/settings.png" width="420" alt="La pestaña Sueldo: el salario base, los complementos, el número de días laborables del mes, la tarifa por hora derivada y la cuadrícula del mes para marcar los días libres.">

Con eso basta para empezar. Todo lo demás es opcional.

## Cómo configurarlo

### Salario base y complementos

Dos campos, porque una nómina tiene al menos dos líneas y los días libres no las tratan igual:

- El **salario base** es la parte de la que sale el permiso sin sueldo.
- Los **complementos** son una cantidad mensual fija — transporte, teléfono — que se paga íntegra hayas tomado o no permiso sin sueldo.

Si no tienes complementos, déjalos en cero y no cambia nada. Si los tienes, separarlos bien es lo que evita que un día de permiso sin sueldo cueste más de lo que cuesta en realidad.

### Días laborables, festivos y permisos

Elige tus días de la semana y marca cualquiera de ellos como **medio día** (un sábado por la mañana, digamos): cuenta como medio en todas partes.

Haz clic en una fecha de la cuadrícula del mes para ir cambiándola: **laborable → festivo pagado → sin sueldo → laborable**. Las flechas a cada lado del título pasan de un mes a otro, y el título mismo te devuelve a hoy, así que los festivos del año que viene pueden entrar antes de llegar.

Los dos tipos de día libre caen en sitios distintos, y esa diferencia es justo de lo que se trata:

|                        | Qué hace                                                                                                                                                                                             |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Festivo **pagado**     | No te cuesta nada. El mismo sueldo cubre ahora menos días laborables, así que cada día que *sí* trabajas vale un poco más. En el festivo mismo no corre nada: su parte viaja en los demás días. |
| Permiso **sin sueldo** | Cuesta un día de salario **base**. Tus complementos llegan igual, íntegros.                                                                                                                    |

Una consecuencia que conviene conocer: marcar como festivo pagado un día **que ya ha pasado** hace que el acumulado del mes baje, porque la parte de ese día ahora hay que ganarla en los días que quedan por delante. Al final del mes vuelve a cuadrar con tu sueldo.

### Horas extra

Desactivadas por defecto. Al activarlas, siguen contando tras la salida con el multiplicador que tú fijes.

Están **limitadas** — cuatro horas por defecto, y nunca más allá de medianoche — porque la app no tiene ni idea de cuándo te fuiste de verdad. Sin techo, un Mac que se queda encendido toda la noche se inventaría una tarde entera de sueldo.

### Objetivos

Añade las cosas para las que estás ahorrando. Cada una muestra lo que cuesta en **días de trabajo** y la fecha en que el horario dice que quedará pagada. Muestra en el panel las que quieras; las demás se quedan en Ajustes.

**Reordénalos con las flechas que hay junto a cada uno, o arrastrando.** Un ringgit solo se puede gastar una vez, así que los objetivos se financian de arriba abajo: uno no empieza a llenarse hasta que los de encima están pagados, y su fecha incluye esa espera. El dinero ya ganado para un objetivo se queda ahí: poner uno nuevo arriba no le quita a otro más antiguo lo que ya cobró.

La fecha **no se mueve mientras trabajas.** Lo que ganas y lo que hace el reloj avanzan a la vez, así que seguir tu horario mantiene la promesa en lugar de aplazarla. Lo único que la desplaza es cambiar el horario que hay debajo: marcar un día libre, quitar un día laborable, acortar la jornada.

### La barra de menús

| Opción                        | Qué hace                                                                                     |
| ----------------------------- | ---------------------------------------------------------------------------------------------- |
| Anillo de progreso            | Un pequeño anillo junto al número, que se va llenando a lo largo del día                     |
| Símbolo de moneda             | Mostrarlo u ocultarlo, para recuperar un carácter de ancho                                   |
| Solo icono fuera del horario  | Encoge el ítem cuando el número no se mueve — tardes, fines de semana, antes de la entrada   |
| **Ocultar importe**           | Saca el dinero de la barra de menús hasta que lo pidas de vuelta, diga lo que diga el reloj  |

**Ocultar importe** es también el primer elemento del panel, a un clic de la barra de menús, para cuando va a empezar una llamada o alguien lee por encima de tu hombro. Nunca oculta *todo*: el anillo se queda, o no quedaría nada donde hacer clic para recuperar el número.

### Abrir al iniciar sesión

Necesita que la app se ejecute desde `/Applications`. Lo que se guarda es lo que pediste: la app se registra al arrancar cuando el interruptor está activado, y nunca se da de baja, porque macOS lista las apps de la barra de menús como ítems de inicio con solo haberse ejecutado una vez y su respuesta no es de fiar en ningún sentido.

## Cómo se calcula el número

```
basic per day     = basic salary ÷ (scheduled days − paid leave)
allowance per day = allowance    ÷ (scheduled days − all leave)
per second        = (basic per day + allowance per day) ÷ paid seconds per day
today             = paid seconds elapsed today × per second
this month        = days already earned × daily pay + today
```

Los dos divisores se cuentan contra el **mes natural real**, así que un mes trabajado entero suma exactamente tu sueldo y la tarifa diaria varía un poco de un mes a otro: agosto de 2026 tiene 21 días laborables, septiembre tiene 22, febrero de 2027 tiene 20.

Las horas pagadas al día salen de la entrada, la salida y el almuerzo. No hay un campo aparte de «horas al día», así que los dos nunca pueden contradecirse.

### No puede desviarse

Cada refresco recalcula desde `(settings, now)` y **no acumula nada**. Cerrar la tapa, dormir, salir y volver a abrir, cambiar el reloj del sistema, cruzar zonas horarias en avión — nada de eso puede hacer que el número esté mal, porque no hay ningún total en marcha que pueda estropearse.

El temporizador solo dice «toca redibujar». No cuenta, y baja a una siesta de 20 segundos siempre que el número está congelado, que es casi todas las tardes y todos los fines de semana.

### No hay botón de pausa, y es a propósito

La cuenta se satura en los dos extremos de la ventana pagada: un instante antes de la jornada vale cero, uno después vale un día entero. Así que el número **se para solo tras la salida y se reinicia solo a medianoche**: ningún temporizador que parar, ningún estado que reiniciar.

Hubo una pausa manual durante un tiempo breve. Era el único estado acumulado de la app y el origen de sus dos peores errores: una pausa que se quedaba activa toda la noche cobraba más que un día laborable entero y dejaba el siguiente a cero, y una pausa iniciada después de la salida hacía que el total diario ya cerrado corriera *hacia atrás*. Borrar la función borró toda la clase de errores.

## Límites conocidos

- **Sin turnos nocturnos.** La salida tiene que ser posterior a la entrada; si no, la app dice «Configuración incompleta» en lugar de mostrar un número equivocado.
- **Sin bonus.** Solo se modelan complementos mensuales fijos. Un pago ocasional o de fin de año tendría que amortizarse en una cifra por segundo para aparecer aquí, y eso adorna el número en vez de describirlo.
- **Sin impuestos, EPF ni SOCSO.** Todas las cifras son brutas.
- **Sin historial.** El acumulado del mes se deriva del horario de este mes, no de un registro de lo que se trabajó de verdad. Editar tu sueldo o tus horas vuelve a poner precio a los días que ya quedaron atrás en el mes en curso.
- **Un solo horario.** Un patrón que no sea semanal — sábados alternos, un turno rotativo — no se puede expresar salvo marcando las excepciones a mano.

## Desarrollo

```bash
make                 # list every target
make test            # 268 tests
make install         # the Mac app, into /Applications
make run             # the iPhone app, on the simulator
```

Clean Architecture orientada a features, un target de SwiftPM por capa, de modo que la dirección de las dependencias la impone el compilador y no la disciplina. Las decisiones de diseño, los invariantes del modelo del dinero y los errores que los moldearon están documentados en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Licencia

MIT — consulta [LICENSE](LICENSE).
