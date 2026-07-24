-- ============================================================
-- Educatech Chatbot - Configuración de Supabase (pgvector)
-- Ejecutar una sola vez en el SQL Editor de Supabase.
-- ============================================================

-- 1. Activar la extensión pgvector
create extension if not exists vector;

-- 2. (Re)crear la tabla documents con vectores de 3072 dimensiones
--    (dimensión del modelo gemini-embedding-001)
drop table if exists documents;

create table documents (
  id bigserial primary key,
  content text,
  metadata jsonb,
  embedding vector(3072)
);

-- 3. (Re)crear la función de búsqueda por similitud.
--    Todas las columnas van calificadas con "documents." para evitar
--    el error 42702 (column reference "id" is ambiguous).
drop function if exists match_documents(vector, int, jsonb);

create or replace function match_documents (
  query_embedding vector(3072),
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    documents.id,
    documents.content,
    documents.metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where documents.metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- Nota: no se crea índice ivfflat/hnsw porque pgvector solo admite índices
-- hasta 2000 dimensiones y aquí usamos 3072. La búsqueda funciona igual
-- (recorrido secuencial), suficiente para el volumen de documentos.