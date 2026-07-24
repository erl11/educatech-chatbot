# Educatech — Chatbot de estudiantes (RAG con Gemini + n8n + Supabase)

## 1. Descripción general del proyecto

Chatbot de atención a estudiantes para la agencia de capacitación **Educatech**.
Los estudiantes escriben sus preguntas en lenguaje natural y el asistente
responde consultando el material de capacitación de los cursos (reglamentos,
políticas, manuales, guías y preguntas frecuentes) que previamente se ha cargado
e indexado.

El objetivo es que un estudiante obtenga respuestas inmediatas y confiables sin
tener que abrir y leer manualmente los documentos, y que el asistente responda
**únicamente** con base en el material oficial de Educatech (sin inventar datos).

Está construido como un workflow de **n8n** usando arquitectura **RAG**
(Retrieval-Augmented Generation): el contenido de los PDFs se convierte en
vectores y, ante cada pregunta, el agente recupera los fragmentos más relevantes
y genera la respuesta con ese contexto.

---

## 2. Arquitectura de la solución

El workflow tiene **dos flujos independientes**:

### Flujo 1 — Cargar / indexar material (equipo Educatech)
```
Formulario web (subir PDF)
  → Divisor de Texto (fragmentos / chunks)
  → Cargador de Documentos (extrae texto del PDF)
  → Embeddings Gemini (gemini-embedding-001)
  → Indexar en Supabase (tabla "documents" con pgvector)
```
El personal sube los PDF de los cursos. El texto se divide en fragmentos, se
convierte en vectores (embeddings) con Gemini y se guarda **permanentemente** en
Supabase. El material persiste aunque se reinicie n8n.

### Flujo 2 — Chatbot para estudiantes
```
Chat (pregunta del estudiante)
  → AI Agent "Chatbot Educatech"
       ├── Modelo Gemini (gemini-flash-latest)   → genera la respuesta
       ├── Memoria de conversación               → mantiene el contexto del chat
       └── Herramienta: Base de Conocimiento (Supabase)
              → Embeddings Gemini (gemini-embedding-001)
              → busca por similitud en la tabla "documents"
```
El agente convierte la pregunta en un vector, busca los fragmentos más parecidos
en Supabase (función `match_documents`) y redacta la respuesta basándose
exclusivamente en ese material.

### Diagrama lógico
```
                    ┌─────────────────────────┐
   PDFs  ─────────► │  Flujo 1: Indexación     │ ──► Supabase (pgvector)
 (equipo)           │  chunks + embeddings     │          ▲
                    └─────────────────────────┘          │ búsqueda por similitud
                                                          │
 Estudiante ─preg─► ┌─────────────────────────┐          │
                    │  Flujo 2: AI Agent       │ ─────────┘
                    │  Gemini + memoria + RAG  │ ──► Respuesta al estudiante
                    └─────────────────────────┘
```

---

## 3. Tecnologías y herramientas utilizadas

| Componente | Tecnología | Uso |
|---|---|---|
| Orquestación / workflow | **n8n** | Conecta y coordina todos los nodos |
| Modelo de lenguaje (LLM) | **Google Gemini** `gemini-flash-latest` | Genera las respuestas del chatbot |
| Embeddings | **Google Gemini** `gemini-embedding-001` (3072 dimensiones) | Convierte texto en vectores |
| Base de datos vectorial | **Supabase** (PostgreSQL + extensión **pgvector**) | Almacena y busca los vectores del material |
| Procesamiento de documentos | Nodos LangChain de n8n (PDF loader + text splitter) | Extrae y fragmenta el texto de los PDFs |
| Entrada de datos | Form Trigger (subida de PDF) y Chat Trigger (preguntas) | Interfaces de carga y de chat |

---

## 4. Instrucciones para ejecutar el proyecto

### Requisitos previos
- Una instancia de **n8n** (cloud o self-hosted).
- Un proyecto de **Supabase** con la extensión `vector` (pgvector).
- Una **API key de Google Gemini** (Google AI Studio).

### Paso 1 — Configurar Supabase
En el proyecto de Supabase, abre el **SQL Editor** y ejecuta el script
[`supabase/setup.sql`](supabase/setup.sql). Crea la tabla `documents` y la
función de búsqueda `match_documents`.

### Paso 2 — Importar el workflow en n8n
1. En n8n: **Workflows → Import from File**.
2. Selecciona [`workflows/educatech-chatbot.json`](workflows/educatech-chatbot.json).

### Paso 3 — Configurar credenciales en n8n
El JSON exportado **no incluye secretos**. Tras importarlo, crea/asigna:

| Credencial | Nodos que la usan |
|---|---|
| **Google Gemini (PaLM) API** | Modelo Gemini, Embeddings Gemini (x2) |
| **Supabase API** (service_role key) | Indexar en Supabase, Base de Conocimiento |

> Importante: en Supabase usa la clave **service_role / secret**, no la `anon`.

### Paso 4 — Cargar el material
Abre la URL del formulario del nodo *Subir material (PDF)* y sube los PDFs de
los cursos, uno por uno. Cada uno queda indexado en Supabase.

### Paso 5 — Probar el chatbot
Abre el chat del workflow (botón **Open chat** en el canvas de n8n) y escribe
una pregunta.

---

## 5. Ejemplos de preguntas que el agente puede responder

- ¿Cuál es la política de reembolso de Educatech?
- ¿Cuánto tiempo tengo para solicitar un reembolso?
- ¿Qué normas debo cumplir como estudiante?
- ¿Cuáles son los horarios de clase?
- ¿Qué pasa si falto a una sesión?
- ¿Cómo obtengo mi certificado al terminar el curso?
- ¿Necesito conocimientos previos para inscribirme?

---

## 6. Ejemplos de respuestas generadas por el agente

> **Pregunta:** ¿Cuál es la política de reembolso?
>
> **Respuesta:** Según la *Política de Reembolso de EducaTech*, puedes solicitar
> la devolución de tu pago dentro de los primeros días posteriores a la
> inscripción, siempre que no hayas superado el porcentaje de avance del curso
> indicado en el documento. Para tramitarlo debes enviar tu solicitud al área
> administrativa. Te recomiendo revisar el documento "Política de Reembolso"
> para los plazos exactos.

> **Pregunta:** ¿Qué obligaciones tengo como estudiante?
>
> **Respuesta:** El *Reglamento del Estudiante EducaTech* establece, entre otras,
> asistir puntualmente a las sesiones, respetar a instructores y compañeros, y
> cumplir con las entregas de cada módulo. Puedes consultar el detalle completo
> en el documento "Reglamento del Estudiante".

> **Pregunta:** ¿Educatech tiene sedes en Europa?
>
> **Respuesta:** No encontré esa información en el material disponible. Te
> recomiendo consultarlo con tu instructor de Educatech.

*(Las respuestas se generan dinámicamente a partir del contenido real de los
PDFs indexados; los ejemplos anteriores son ilustrativos.)*

---

## Modelos usados

| Función | Modelo | Notas |
|---|---|---|
| Chat | `models/gemini-flash-latest` | Respuestas del asistente |
| Embeddings | `models/gemini-embedding-001` | 3072 dimensiones |

> Si cambias el modelo de embeddings, debes recrear la tabla `documents` con la
> dimensión correcta y volver a subir los PDFs.

---

## Notas de seguridad

- Las credenciales (API keys de Gemini y Supabase) **no** se versionan; se
  configuran dentro de n8n.
- Los PDFs de material están excluidos en `.gitignore`.