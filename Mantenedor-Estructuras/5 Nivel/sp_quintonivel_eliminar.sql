-- FUNCTION: public.sp_quintonivel_eliminar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying)
-- Eliminar quinto nivel

-- DROP FUNCTION IF EXISTS public.sp_quintonivel_eliminar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_quintonivel_eliminar(
	p_refcursor refcursor,
	p_pquintonivelid character varying,
	p_pdivisionid character varying,
	p_pcentrocostoid character varying,
	p_pdepartamentoid character varying,
	p_plugarpagoid character varying,
	p_pempresaid character varying,
	p_pusuarioid character varying
)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_mensaje text := '';
    var_error   integer := 0;
BEGIN
    -- 1) Verificar que exista
    IF EXISTS (
        SELECT 1
          FROM quinto_nivel
         WHERE quintonivelid = p_pquintonivelid
           AND divisionid = p_pdivisionid
           AND centrocostoid = p_pcentrocostoid
           AND departamentoid = p_pdepartamentoid
           AND lugarpagoid = p_plugarpagoid
           AND empresaid = p_pempresaid
    ) THEN
        -- 2) Verificar que no tenga dependencias (empleados o documentos)
        IF NOT EXISTS (
            SELECT 1 FROM empleados
            WHERE quintonivelid = p_pquintonivelid
              AND divisionid = p_pdivisionid
              AND centrocostoid = p_pcentrocostoid
              AND departamentoid = p_pdepartamentoid
              AND lugarpagoid = p_plugarpagoid
              AND rutempresa = p_pempresaid
        ) AND NOT EXISTS (
            SELECT 1 FROM g_documentosinfo
            WHERE quintonivelid = p_pquintonivelid
              AND divisionid = p_pdivisionid
              AND centrocostoid = p_pcentrocostoid
              AND departamentoid = p_pdepartamentoid
              AND lugarpagoid1 = p_plugarpagoid
              AND empresaid = p_pempresaid
        ) THEN
            -- 3) Intentar eliminar
            BEGIN
                DELETE FROM quinto_nivel
                WHERE quintonivelid = p_pquintonivelid
                  AND divisionid = p_pdivisionid
                  AND centrocostoid = p_pcentrocostoid
                  AND departamentoid = p_pdepartamentoid
                  AND lugarpagoid = p_plugarpagoid
                  AND empresaid = p_pempresaid;
                
                var_mensaje := '';
                var_error   := 0;
            EXCEPTION WHEN OTHERS THEN
                var_mensaje := 'Error al eliminar quinto nivel: ' || SQLERRM;
                var_error   := 2;
            END;
        ELSE
            var_mensaje := 'No se puede eliminar el Quinto Nivel porque tiene Empleados o Documentos asociados';
            var_error   := 3;
        END IF;
    ELSE
        var_mensaje := 'El Quinto Nivel no existe';
        var_error   := 1;
    END IF;

    -- 4) Devolver resultado en cursor
    OPEN p_refcursor FOR
    SELECT var_mensaje AS "mensaje", var_error AS "error";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_quintonivel_eliminar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_quintonivel_eliminar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying)
    IS 'Eliminar quinto nivel';
