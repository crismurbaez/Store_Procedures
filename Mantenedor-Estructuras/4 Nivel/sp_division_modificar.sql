-- FUNCTION: public.sp_division_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
-- Modificar división existente

DROP FUNCTION IF EXISTS public.sp_division_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_division_modificar(
    p_refcursor refcursor,
    p_pdivisionid character varying,
    p_pnombredivision character varying,
    p_pempresaid character varying,
    p_plugarpagoid character varying,
    p_pdepartamentoid character varying,
    p_pcentrocostoid character varying,
    p_pdireccion character varying,
    p_pcomuna character varying,
    p_pciudad character varying,
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
          FROM division
         WHERE divisionid = p_pdivisionid
           AND centrocostoid = p_pcentrocostoid
           AND departamentoid = p_pdepartamentoid
           AND lugarpagoid = p_plugarpagoid
           AND empresaid = p_pempresaid
    ) THEN
        -- 2) Intentar actualizar
        BEGIN
            UPDATE division SET
                nombredivision = p_pnombredivision,
                direccion = p_pdireccion,
                comuna = p_pcomuna,
                ciudad = p_pciudad,
                fechamodificacion = now(),
                usuarioidmodificacion = p_pusuarioid
            WHERE divisionid = p_pdivisionid
              AND centrocostoid = p_pcentrocostoid
              AND departamentoid = p_pdepartamentoid
              AND lugarpagoid = p_plugarpagoid
              AND empresaid = p_pempresaid;
            
            var_mensaje := '';
            var_error   := 0;
        EXCEPTION WHEN OTHERS THEN
            var_mensaje := 'Error al modificar División: ' || SQLERRM;
            var_error   := 2;
        END;
    ELSE
        var_mensaje := 'El División no existe';
        var_error   := 1;
    END IF;

    -- 3) DEBUG NOTICE
    IF p_debug <> 0 THEN
        RAISE NOTICE 'UPDATE division SET nombredivision=%, direccion=%, comuna=%, ciudad=%, fechamodificacion=now(), usuarioidmodificacion=% WHERE divisionid=% AND centrocostoid=% AND departamentoid=% AND lugarpagoid=% AND empresaid=%',
             p_pnombredivision, p_pdireccion, p_pcomuna, p_pciudad, p_pusuarioid,
             p_pdivisionid, p_pcentrocostoid, p_pdepartamentoid, p_plugarpagoid, p_pempresaid;
    END IF;

    -- 4) Devolver resultado en cursor
    OPEN p_refcursor FOR
    SELECT var_mensaje AS "mensaje", var_error AS "error";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_division_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_division_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    IS 'Modificar División existente';