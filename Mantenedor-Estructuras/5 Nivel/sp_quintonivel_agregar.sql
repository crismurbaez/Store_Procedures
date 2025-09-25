-- FUNCTION: public.sp_quintonivel_agregar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
-- Agregar nuevo quinto nivel

-- DROP FUNCTION IF EXISTS public.sp_quintonivel_agregar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_quintonivel_agregar(
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
    -- 1) Verificar que no exista ya
    IF NOT EXISTS (
        SELECT 1
          FROM quinto_nivel
         WHERE quintonivelid = p_pquintonivelid
           AND divisionid = p_pdivisionid
           AND centrocostoid = p_pcentrocostoid
           AND departamentoid = p_pdepartamentoid
           AND lugarpagoid = p_plugarpagoid
           AND empresaid = p_pempresaid
    ) THEN
        -- 2) Intentar insertar
        BEGIN
            INSERT INTO quinto_nivel (
                quintonivelid,
                nombrequintonivel,
                empresaid,
                direccion,
                comuna,
                ciudad,
                departamentoid,
                lugarpagoid,
                centrocostoid,
                divisionid,
                fechacreacion,
                usuarioid
            ) VALUES (
                p_pquintonivelid,
                p_pnombrequintonivel,
                p_pempresaid,
                p_pdireccion,
                p_pcomuna,
                p_pciudad,
                p_pdepartamentoid,
                p_plugarpagoid,
                p_pcentrocostoid,
                p_pdivisionid,
                now(),
                p_pusuarioid
            );
            var_mensaje := '';
            var_error   := 0;
        EXCEPTION WHEN OTHERS THEN
            var_mensaje := 'Error al agregar quinto nivel: ' || SQLERRM;
            var_error   := 2;
        END;
    ELSE
        var_mensaje := 'El Quinto Nivel ya existe';
        var_error   := 1;
    END IF;

    -- 3) DEBUG NOTICE
    IF p_debug <> 0 THEN
        RAISE NOTICE 'INSERT INTO quinto_nivel … VALUES(%, %, %, %, %, %, %, %, %, %, now(), %)',
            p_pquintonivelid, p_pnombrequintonivel, p_pempresaid, p_pdireccion,
            p_pcomuna, p_pciudad, p_pdepartamentoid, p_plugarpagoid, p_pcentrocostoid, p_pdivisionid, p_pusuarioid;
    END IF;

    -- 4) Devolver resultado en cursor
    OPEN p_refcursor FOR
    SELECT var_mensaje AS "mensaje", var_error AS "error";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_quintonivel_agregar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_quintonivel_agregar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    IS 'Agregar nuevo quinto nivel';
