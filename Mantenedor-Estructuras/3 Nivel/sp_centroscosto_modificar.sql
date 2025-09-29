-- FUNCTION: public.sp_centroscosto_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
-- Modificar centro de costo existente

DROP FUNCTION IF EXISTS public.sp_centroscosto_modificar(refcursor, varchar, varchar, varchar, varchar, varchar, varchar, varchar, int4);

CREATE OR REPLACE FUNCTION public.sp_centroscosto_modificar(
	p_refcursor refcursor,
	p_pcentrocostoid character varying,
	p_pnombrecentrocosto character varying,
	p_pempresaid character varying,
	p_plugarpagoid character varying,
	p_pdepartamentoid character varying,
	p_pusuarioid character varying,
	p_debug integer DEFAULT 0
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
        -- 2) Intentar actualizar
        BEGIN
            UPDATE centroscosto SET
                nombrecentrocosto = p_pnombrecentrocosto,
                fechamodificacion = now(),
                usuarioidmodificacion = p_pusuarioid
            WHERE centrocostoid = p_pcentrocostoid
              AND departamentoid = p_pdepartamentoid
              AND lugarpagoid = p_plugarpagoid
              AND empresaid = p_pempresaid;
            
            var_mensaje := '';
            var_error   := 0;
        EXCEPTION WHEN OTHERS THEN
            var_mensaje := 'Error al modificar centro de costo: ' || SQLERRM;
            var_error   := 2;
        END;
    ELSE
        var_mensaje := 'El Centro de Costo no existe';
        var_error   := 1;
    END IF;

    -- 3) DEBUG NOTICE
    IF p_debug <> 0 THEN
        RAISE NOTICE 'UPDATE centroscosto SET nombrecentrocosto=%, fechamodificacion=now(), usuarioidmodificacion=% WHERE centrocostoid=% AND departamentoid=% AND lugarpagoid=% AND empresaid=%',
            p_pnombrecentrocosto, p_pusuarioid,
            p_pcentrocostoid, p_pdepartamentoid, p_plugarpagoid, p_pempresaid;
    END IF;

    -- 4) Devolver resultado en cursor
    OPEN p_refcursor FOR
    SELECT var_mensaje AS "mensaje", var_error AS "error";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_centroscosto_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_centroscosto_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    IS 'Modificar centro de costo existente';
