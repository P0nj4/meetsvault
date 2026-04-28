# Manual de usuario de MeetsVault

## 1. ¿Qué es MeetsVault?

MeetsVault es una aplicación de barra de menú para macOS que graba tus reuniones y las convierte en texto, todo directamente en tu Mac. Captura tanto tu micrófono como el audio de los demás participantes (audio del sistema) y luego transcribe todo de forma local usando un modelo de inteligencia artificial Whisper. Ningún audio, ninguna transcripción ni ningún dato personal abandona tu computadora. No hay cuenta, no hay suscripción y no se necesita conexión a internet una vez que el modelo Whisper está descargado.

---

## 2. Requisitos

- **macOS 15 Sequoia o posterior**
- **Mac con Apple Silicon** (M1 o posterior)
- **Espacio en disco** para el modelo Whisper que elijas (de 75 MB a 3 GB; consulta la tabla de modelos en la sección 10)

---

## 3. Instalación

1. Descarga `MeetsVault.zip` y descomprímelo. Obtendrás `MeetsVault.app`.
2. Arrastra `MeetsVault.app` a tu carpeta `/Applications`.
3. **Primer lanzamiento:** no hagas doble clic en la app. En cambio, haz clic derecho (o Control-clic) sobre `MeetsVault.app` y elige **Abrir**. Haz clic en **Abrir** de nuevo en el diálogo que aparece. Este paso único es necesario porque la app no está firmada por la Mac App Store. Después del primer lanzamiento puedes abrirla normalmente.

---

## 4. Primer lanzamiento — Asistente de configuración

La primera vez que abres MeetsVault, un asistente de configuración te guía por siete pasos. Solo necesitas hacerlo una vez.

### Paso 1 — Bienvenida

Una breve introducción a la aplicación. Haz clic en **Siguiente** para continuar.

### Paso 2 — Términos y condiciones

Lee los términos, marca la casilla para confirmar que los aceptas y haz clic en **Siguiente**. No puedes continuar sin aceptarlos. Puedes releerlos más tarde desde **Terms & Conditions** en la barra de menú.

### Paso 3 — Elegir un modelo de transcripción

Elige el modelo Whisper que mejor se adapte a tus necesidades. Los modelos van desde los más pequeños y rápidos hasta los más grandes y precisos. **small** está seleccionado por defecto y es la opción correcta para la mayoría de las personas.

| Modelo | Tamaño | Notas |
|---|---|---|
| tiny | 75 MB | El más rápido, el menos preciso |
| base | 142 MB | Uso casual cuando la velocidad importa más que la precisión |
| small | 466 MB | **Recomendado** — buena precisión a velocidad razonable |
| medium | 1,5 GB | Mejor con acentos, términos técnicos o varios idiomas |
| large-v3 | 3 GB | Mayor precisión; lento y necesita más RAM |

Puedes cambiar de modelo más tarde desde la barra de menú (ver sección 10).

### Paso 4 — Dónde guardar las grabaciones

Elige la carpeta donde MeetsVault guardará tus archivos de transcripción y audio. La ubicación predeterminada es `~/Meetings` (una carpeta `Meetings` en tu directorio de inicio). Haz clic en **Elegir…** para seleccionar otra ubicación. Haz clic en **Siguiente** cuando estés listo.

### Paso 5 — Conceder permisos

MeetsVault necesita dos permisos de macOS para grabar tus reuniones:

**Micrófono**
Captura tu voz. Al hacer clic en **Solicitar permisos**, macOS mostrará un diálogo pidiendo acceso al micrófono. Haz clic en **Permitir**.

Si el diálogo no aparece o lo denegaste por accidente:
1. Abre **Configuración del Sistema**
2. Ve a **Privacidad y seguridad → Micrófono**
3. Busca **MeetsVault** en la lista y actívalo

**Grabación de pantalla**
Se utiliza para capturar el audio de los demás participantes en la llamada — sus voces llegan a través del audio del sistema de tu Mac. Tu pantalla nunca se graba ni se guarda; solo se usa el flujo de audio.

Al hacer clic en **Solicitar permisos**, macOS te llevará a Configuración del Sistema. Busca **MeetsVault** en la lista de **Privacidad y seguridad → Grabación de pantalla** y actívalo.

> **Importante:** Después de conceder el permiso de Grabación de pantalla por primera vez, necesitas **cerrar MeetsVault y volver a abrirlo** para que el permiso surta efecto. Sin este paso, el audio de los demás participantes estará en silencio.

Una vez que ambos permisos muestren una marca de verificación verde, haz clic en **Descargar modelo**.

### Paso 6 — Descarga del modelo

MeetsVault descarga el modelo Whisper que seleccionaste. Una barra de progreso muestra el estado de la descarga. Esta es la única vez que la app necesita conexión a internet. El modelo se almacena localmente y nunca se vuelve a descargar (a menos que lo elimines).

Si la descarga falla, haz clic en **Reintentar**. Asegúrate de tener suficiente espacio libre en disco y una conexión a internet funcional.

### Paso 7 — Listo

La configuración está completa. Haz clic en **Finalizar**. MeetsVault ahora está en tu barra de menú como un ícono de forma de onda.

---

## 5. Uso diario — La barra de menú

Haz clic en el ícono de forma de onda en la barra de menú para abrir el menú de MeetsVault.

**Cuando está inactivo:**
- **Start Recording** — comienza a grabar tu micrófono y el audio del sistema simultáneamente.

**Durante la grabación:**
- **● Recording · MM:SS** — muestra el tiempo transcurrido (solo lectura, no es un botón).
- **Stop Recording** — detiene la grabación y comienza inmediatamente la transcripción.

**Durante la transcripción:**
- **Transcribing…** — se muestra mientras el modelo de IA procesa el audio. El ícono se anima. No puedes iniciar una nueva grabación hasta que finalice la transcripción.

**Siempre disponible:**
- **Open Meetings Folder** — abre tu carpeta de reuniones en el Finder.
- **Recent Transcripts** — un submenú que lista los 5 archivos `.md` modificados más recientemente en tu carpeta de reuniones. Haz clic en cualquier elemento para abrirlo en tu app de Markdown predeterminada.
- **Language: [nombre]** — muestra el idioma de transcripción actual. Haz clic para cambiarlo. Opciones rápidas: inglés, español, francés, alemán, portugués, italiano, japonés, chino, coreano, ruso. Para otros idiomas (árabe, checo, neerlandés, finlandés, polaco, sueco, turco y más), elige **More Languages…** para obtener instrucciones sobre cómo configurar un código de idioma manualmente.
- **Model: [nombre]** — muestra el modelo Whisper activo. Haz clic en **Switch Model** para abrir la ventana de selección de modelo y descargar una variante diferente.
- **Re-transcribe audio…** — abre un selector de archivos. Selecciona cualquier archivo `.wav` y MeetsVault lo transcribirá de nuevo usando el modelo e idioma actuales. Útil después de cambiar a un modelo más preciso o de cambiar el idioma.
- **About MeetsVault** — información de versión y compilación.
- **Terms & Conditions** — vuelve a abrir los términos que aceptaste durante la configuración.
- **Quit MeetsVault** — cierra la aplicación.

---

## 6. Dónde están tus archivos

Todos los archivos de transcripción y audio se guardan en tu carpeta de reuniones (predeterminada: `~/Meetings`).

**Formato de nombre de archivo:**

```
AAAA-MM-DD_HHMM_titulo-de-la-reunion.md
AAAA-MM-DD_HHMM_titulo-de-la-reunion.wav
```

Ejemplo:

```
2026-04-27_1430_sincronizacion-semanal.md
2026-04-27_1430_sincronizacion-semanal.wav
```

Si inicias una grabación sin proporcionar un título (desde la barra de menú), el nombre de archivo será `untitled`.

**Limpieza automática de audio a los 7 días:** Cada vez que MeetsVault se inicia, elimina automáticamente los archivos `.wav` en tu carpeta de reuniones que tengan más de 7 días de antigüedad. Los archivos de transcripción (`.md`) **nunca** se eliminan automáticamente. Si quieres conservar un archivo de audio permanentemente, muévelo fuera de la carpeta de reuniones antes de que pasen los 7 días.

---

## 7. Formato del archivo de transcripción

Cada archivo `.md` comienza con un bloque de metadatos YAML seguido de la transcripción:

```markdown
---
title: Sincronización semanal
date: 2026-04-27
started_at: 14:30:05
ended_at: 15:12:48
duration: 00:42:43
language: es
model: whisperkit-small
audio_source: system+microphone
audio_file: 2026-04-27_1430_sincronizacion-semanal.wav
---

# Sincronización semanal

## Transcript

[00:00:00] Muy bien, empecemos.

[00:00:08] Gracias a todos por unirse.
```

Los marcadores de tiempo `[HH:MM:SS]` indican cuándo se pronunció cada segmento, medido desde el inicio de la grabación.

Puedes abrir los archivos `.md` en cualquier editor de Markdown — Obsidian, iA Writer, VS Code o el TextEdit simple funcionan perfectamente.

---

## 8. Notificaciones

MeetsVault envía dos tipos de notificaciones del sistema:

- **Transcripción lista** — aparece cuando finaliza la transcripción. Haz clic en la notificación para abrir el archivo de transcripción directamente.
- **Recordatorio de grabación activa** — si dejas una grabación en marcha, MeetsVault envía un recordatorio cada hora para que no olvides detenerla.

Asegúrate de que las notificaciones estén habilitadas para MeetsVault en **Configuración del Sistema → Notificaciones**.

---

## 9. Automatización — Esquema de URL

MeetsVault responde al esquema de URL `meetsvault://`, por lo que puedes controlarlo desde scripts, Shortcuts, aplicaciones de calendario o cualquier herramienta que pueda abrir una URL.

**Iniciar una grabación:**

```
meetsvault://start?title=Tu+Nombre+de+Reunion
```

**Detener la grabación actual:**

```
meetsvault://stop
```

**Desde la terminal:**

```bash
open "meetsvault://start?title=Reunion+Semanal"
open "meetsvault://stop"
```

**Desde Shortcuts.app:**
Crea un atajo con una acción **Abrir URLs** y pega la URL anterior. Luego puedes ejecutar el atajo desde la barra de menú, desde Spotlight o asignarle un atajo de teclado.

**Desde una aplicación de calendario o webhook:**
Cualquier herramienta que pueda abrir una URL puede iniciar una grabación. Apunta el campo "abrir URL al inicio" del evento de tu calendario a `meetsvault://start?title=Nombre+de+Reunion`.

> **Consejo:** Puedes crear una habilidad de Claude Code que ejecute `meetsvault://start` cuando digas "iniciar la reunión" — el esquema de URL está diseñado exactamente para este tipo de automatización.

---

## 10. Cambiar de modelo Whisper

Puedes cambiar el modelo Whisper en cualquier momento desde la barra de menú:

1. Haz clic en el ícono de forma de onda → **Model: [nombre]** → **Switch Model**.
2. Se abre la ventana de selección de modelo. Elige una variante.
3. Si el modelo aún no está descargado, haz clic en **Download**. Una barra de progreso sigue la descarga.
4. Una vez descargado, el nuevo modelo se usará en todas las grabaciones futuras.

**Comparación de modelos:**

| Modelo | Tamaño | Velocidad | Precisión |
|---|---|---|---|
| tiny | 75 MB | Muy rápida | Básica |
| base | 142 MB | Rápida | Aceptable |
| small | 466 MB | Moderada | Buena (predeterminado) |
| medium | 1,5 GB | Lenta | Mejor |
| large-v3 | 3 GB | La más lenta | La mejor |

Todos los modelos se ejecutan completamente en tu Mac. Los modelos más grandes requieren más RAM y tardan más en transcribir, pero producen menos errores, especialmente con acentos, vocabulario técnico o idiomas distintos al inglés.

Los modelos descargados se almacenan en `~/Library/Application Support/MeetsVault/models/` y no es necesario descargarlos de nuevo.

---

## 11. Privacidad

MeetsVault no realiza ninguna llamada de red durante la grabación o la transcripción. La única vez que se conecta a internet es cuando descarga un modelo Whisper por primera vez (los modelos provienen de Hugging Face). Una vez descargado, el modelo reside en tu Mac y nunca se vuelve a buscar a menos que lo elimines. Nada sobre tus reuniones — ni el audio, ni la transcripción, ni el título — se envía jamás a ningún servidor.

---

## 12. Solución de problemas

**No se escucha la voz de la otra persona en la transcripción**
El permiso de Grabación de pantalla no está activo. Abre **Configuración del Sistema → Privacidad y seguridad → Grabación de pantalla**, activa MeetsVault y luego **cierra y vuelve a abrir** la aplicación. Este reinicio es necesario para que el permiso surta efecto.

**Mi micrófono está en silencio / solo se captura el audio del otro lado**
El permiso de Micrófono no está concedido. Abre **Configuración del Sistema → Privacidad y seguridad → Micrófono** y activa MeetsVault.

**La descarga del modelo falló**
Abre la barra de menú → **Model: [nombre]** → **Switch Model**, selecciona el mismo modelo y haz clic en **Download** de nuevo. Asegúrate de tener suficiente espacio libre en disco (consulta el tamaño en la tabla de modelos anterior) y una conexión a internet funcional.

**Quiero conservar mi archivo de audio `.wav`**
Mueve el archivo fuera de tu carpeta de reuniones (por ejemplo, al Escritorio u otra carpeta). MeetsVault solo elimina archivos `.wav` dentro de la carpeta de reuniones que tengan más de 7 días de antigüedad. Los archivos movidos a otro lugar no se tocan.

**Perdí un archivo `.wav` que fue eliminado automáticamente**
Una vez eliminado, el archivo no se puede recuperar. De ahora en adelante, mueve los archivos de audio que quieras conservar fuera de la carpeta de reuniones inmediatamente después de grabar. Tu transcripción (`.md`) siempre se conserva.
