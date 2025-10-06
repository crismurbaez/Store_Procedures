-- Script para agregar campo quintonivelid a la tabla contratodatosvariables
-- Fecha: 2025-01-02
-- Propósito: Permitir soporte completo de niveles 1-5 en contratodatosvariables
-- Respeta la estructura original de la tabla

-- =====================================================
-- PASO 1: Agregar columna quintonivelid siguiendo estructura original
-- =====================================================

-- Agregar la columna quintonivelid respetando la estructura existente
-- Ubicación: Después de divisionid (siguiendo orden lógico de niveles)
ALTER TABLE public.contratodatosvariables 
ADD COLUMN quintonivelid character varying(14) COLLATE pg_catalog."default";

-- =====================================================
-- PASO 2: Verificación de la modificación
-- =====================================================

-- Verificar que la columna fue agregada correctamente
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable,
    ordinal_position
FROM information_schema.columns 
WHERE table_name = 'contratodatosvariables' 
  AND table_schema = 'public'
  AND column_name IN ('lugarpagoid', 'departamentoid', 'centrocosto', 'divisionid', 'quintonivelid')
ORDER BY ordinal_position;

-- Verificar estructura completa de la tabla
\d public.contratodatosvariables;

-- =====================================================
-- PASO 3: Script de rollback (en caso de problemas)
-- =====================================================

-- Para revertir los cambios si es necesario:
-- ALTER TABLE public.contratodatosvariables DROP COLUMN IF EXISTS quintonivelid;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

/*
ESTRUCTURA RESPETADA:
- Tipo de dato: character varying(14) (igual que otros campos de niveles)
- Collation: pg_catalog."default" (igual que otros campos)
- Ubicación: Después de divisionid (orden lógico de niveles)
- Nullable: Sí (permite valores NULL como otros campos)

ANTES DE EJECUTAR:
1. BACKUP: Hacer backup completo de la BD
2. TESTING: Probar en ambiente de desarrollo primero
3. APLICACIONES: Verificar que las aplicaciones puedan manejar el nuevo campo
4. STORED PROCEDURES: Actualizar SPs que usen contratodatosvariables

ORDEN DE EJECUCIÓN:
1. Ejecutar en ambiente de desarrollo
2. Probar funcionalidad completa
3. Hacer backup de producción
4. Ejecutar en producción
5. Verificar funcionamiento
6. Actualizar documentación

ESTRUCTURA FINAL ESPERADA:
lugarpagoid character varying(14)     -- Nivel 1
departamentoid character varying(14)  -- Nivel 2
centrocosto character varying(14)     -- Nivel 3
divisionid character varying(14)      -- Nivel 4
quintonivelid character varying(14)   -- Nivel 5 (NUEVO)
*/
