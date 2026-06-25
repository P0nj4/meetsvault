# XPeng G6 Manual — Diseño

**Fecha:** 2026-06-25
**Estado:** Aprobado

## Problema

El manual del XPeng G6 es un PDF de 370 páginas en inglés. Es demasiado grande para pasarlo directamente a Claude en cada consulta. Se necesita un formato que permita:

- Consultar el manual desde Claude Code (terminal) y desde la app de Claude en mobile
- Leer el contenido directamente en un browser sin necesidad de IA
- Acceder a las imágenes del manual por URL

## Solución

Sitio estático **MkDocs Material** en **GitHub Pages**, con el contenido del manual traducido al español. Claude navega el sitio con WebFetch: primero fetcha el índice para orientarse, luego fetcha el capítulo relevante.

URL final: `https://<usuario>.github.io/xpeng-g6-manual/`

---

## Arquitectura

### Repositorio

```
xpeng-g6-manual/
├── docs/
│   ├── index.md              # Índice con descripción de cada capítulo
│   ├── cap01-seguridad.md
│   ├── cap02-...md
│   └── images/
│       ├── cap01-img01.png
│       └── ...
├── mkdocs.yml
├── scripts/
│   └── convert.py            # Script de conversión PDF → Markdown
└── .github/
    └── workflows/
        └── deploy.yml
```

### Componentes

| Componente | Responsabilidad |
|---|---|
| `scripts/convert.py` | Extrae texto e imágenes del PDF, traduce al español con Claude, escribe los `.md` |
| `docs/` | Contenido Markdown generado (commiteado al repo) |
| `mkdocs.yml` | Configuración del sitio MkDocs Material en español |
| `deploy.yml` | GitHub Action: buildea y despliega a `gh-pages` en cada push a `main` |

---

## Pipeline de conversión (`convert.py`)

Corre localmente una sola vez. Es idempotente.

1. **Extracción** — `PyMuPDF` lee el PDF. Detecta los capítulos usando los marcadores del índice del PDF (`doc.get_toc()`). Extrae el texto de cada capítulo y guarda las imágenes en `docs/images/` con el naming `capXX-imgYY.png`.

2. **Traducción** — Claude SDK con autenticación OAuth (sin API key). Envía el texto de cada capítulo en un prompt que pide traducir al español preservando la estructura Markdown y los referencias a imágenes. Los capítulos se procesan secuencialmente; el script guarda progreso para poder retomar si se interrumpe.

3. **Escritura** — Genera un `.md` por capítulo en `docs/`. Las imágenes se referencian como `![descripción](../images/capXX-imgYY.png)`.

4. **Índice** — Genera `docs/index.md` con la lista completa de capítulos, sus títulos en español y una descripción breve de cada uno (generada por Claude). Este es el punto de entrada para Claude cuando consulta el manual.

---

## MkDocs

**Tema:** Material for MkDocs  
**Idioma:** español  
**Plugin de búsqueda:** activado con `lang: es`

```yaml
site_name: XPeng G6 — Manual de Usuario
theme:
  name: material
  language: es
plugins:
  - search:
      lang: es
```

La navegación (`nav:`) se genera automáticamente por el script de conversión al final del proceso.

---

## GitHub Actions

Archivo: `.github/workflows/deploy.yml`

- **Trigger:** push a `main`
- **Pasos:** checkout → instalar Python + MkDocs Material → `mkdocs build` → deploy a `gh-pages`
- El script de conversión **no** corre en CI. El contenido Markdown se commitea al repo y CI solo buildea el HTML.

---

## Flujo de uso con Claude

### Claude Code / Claude mobile

```
1. fetch https://<usuario>.github.io/xpeng-g6-manual/
   → lee el índice, identifica el capítulo relevante

2. fetch https://<usuario>.github.io/xpeng-g6-manual/cap05-sistemas-asistencia/
   → lee el contenido del capítulo

3. Responde con la información + link directo a la imagen si aplica
   → ej: "Ver diagrama: https://.../images/cap05-img03.png"
```

### Lectura directa

El usuario abre `https://<usuario>.github.io/xpeng-g6-manual/` en el browser. Tiene buscador integrado, navegación lateral, e imágenes inline.

---

## Decisiones

- **MkDocs sobre Docusaurus:** menos configuración, Python nativo (mismo ecosistema que el script de conversión).
- **GitHub Pages sobre Vercel:** suficiente para contenido estático, sin necesidad de features extra.
- **OAuth sobre API key:** el usuario usa su suscripción de Claude.ai existente.
- **Conversión local, no en CI:** evita exponer credenciales OAuth en el entorno de CI.
