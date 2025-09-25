-- FUNCTION: public.sp_centroscosto_eliminar(refcursor, character varying, character varying, character varying, character varying, character varying)
-- Eliminar centro de costo

-- DROP FUNCTION IF EXISTS public.sp_centroscosto_eliminar(refcursor, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_centroscosto_eliminar(
	p_refcursor refcursor,
	p_pempresaid character varying,
	p_plugarpagoid character varying,
	p_pdepartamentoid character varying,
	p_pcentrocostoid character varying,
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
          FROM centroscosto
         WHERE centrocostoid = p_pcentrocostoid
           AND departamentoid = p_pdepartamentoid
           AND lugarpagoid = p_plugarpagoid
           AND empresaid = p_pempresaid
    ) THEN
        -- 2) Verificar que no tenga dependencias (niveles inferiores)
        IF NOT EXISTS (
            SELECT 1 FROM division
            WHERE centrocostoid = p_pcentrocostoid
              AND departamentoid = p_pdepartamentoid
              AND lugarpagoid = p_plugarpagoid
              AND empresaid = p_pempresaid
        ) THEN
            -- 3) Intentar eliminar
            BEGIN
                DELETE FROM centroscosto
                WHERE centrocostoid = p_pcentrocostoid
                  AND departamentoid = p_pdepartamentoid
                  AND lugarpagoid = p_plugarpagoid
                  AND empresaid = p_pempresaid;
                
                var_mensaje := '';
                var_error   := 0;
            EXCEPTION WHEN OTHERS THEN
                var_mensaje := 'Error al eliminar el Nivel: ' || SQLERRM;
                var_error   := 2;
            END;
        ELSE
            var_mensaje := 'No se puede eliminar el Centro de Costo porque tiene Niveles asociados';
            var_error   := 3;
        END IF;
    ELSE
        var_mensaje := 'El Nivel no existe';
        var_error   := 1;
    END IF;

    -- 4) Devolver resultado en cursor
    OPEN p_refcursor FOR
    SELECT var_mensaje AS "mensaje", var_error AS "error";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_centroscosto_eliminar(refcursor, character varying, character varying, character varying, character varying, character varying)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_centroscosto_eliminar(refcursor, character varying, character varying, character varying, character varying, character varying)
    IS 'Eliminar centro de costo';
