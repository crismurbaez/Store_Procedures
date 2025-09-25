-- FUNCTION: public.sp_quintonivel_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
-- Modificar quinto nivel existente

-- DROP FUNCTION IF EXISTS public.sp_quintonivel_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_quintonivel_modificar(
	p_refcursor refcursor,
	p_pquintonivelid character varying,
	p_pnombrequintonivel character varying,
	p_pdivisionid character varying,
	p_pcentrocostoid character varying,
	p_pdepartamentoid character varying,
	p_plugarpagoid character varying,
	p_pempresaid character varying,
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
          FROM quinto_nivel
         WHERE quintonivelid = p_pquintonivelid
           AND divisionid = p_pdivisionid
           AND centrocostoid = p_pcentrocostoid
           AND departamentoid = p_pdepartamentoid
           AND lugarpagoid = p_plugarpagoid
           AND empresaid = p_pempresaid
    ) THEN
        -- 2) Intentar actualizar
        BEGIN
            UPDATE quinto_nivel SET
                nombrequintonivel = p_pnombrequintonivel,
                direccion = p_pdireccion,
                comuna = p_pcomuna,
                ciudad = p_pciudad,
                fechamodificacion = now(),
                usuarioidmodificacion = p_pusuarioid
            WHERE quintonivelid = p_pquintonivelid
              AND divisionid = p_pdivisionid
              AND centrocostoid = p_pcentrocostoid
              AND departamentoid = p_pdepartamentoid
              AND lugarpagoid = p_plugarpagoid
              AND empresaid = p_pempresaid;
            
            var_mensaje := '';
            var_error   := 0;
        EXCEPTION WHEN OTHERS THEN
            var_mensaje := 'Error al modificar quinto nivel: ' || SQLERRM;
            var_error   := 2;
        END;
    ELSE
        var_mensaje := 'El Quinto Nivel no existe';
        var_error   := 1;
    END IF;

    -- 3) DEBUG NOTICE
    IF p_debug <> 0 THEN
        RAISE NOTICE 'UPDATE quinto_nivel SET nombrequintonivel=%, direccion=%, comuna=%, ciudad=%, fechamodificacion=now(), usuarioidmodificacion=% WHERE quintonivelid=% AND divisionid=% AND centrocostoid=% AND departamentoid=% AND lugarpagoid=% AND empresaid=%',
            p_pnombrequintonivel, p_pdireccion, p_pcomuna, p_pciudad, p_pusuarioid,
            p_pquintonivelid, p_pdivisionid, p_pcentrocostoid, p_pdepartamentoid, p_plugarpagoid, p_pempresaid;
    END IF;

    -- 4) Devolver resultado en cursor
    OPEN p_refcursor FOR
    SELECT var_mensaje AS "mensaje", var_error AS "error";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_quintonivel_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_quintonivel_modificar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    IS 'Modificar quinto nivel existente';
