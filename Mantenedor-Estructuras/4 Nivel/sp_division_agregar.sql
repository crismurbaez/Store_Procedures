-- FUNCTION: public.sp_division_agregar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
-- Agregar nueva división

-- DROP FUNCTION IF EXISTS public.sp_division_agregar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_division_agregar(
	p_refcursor refcursor,
	p_pdivisionid character varying,
	p_pnombredivision character varying,
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
          FROM division
         WHERE divisionid = p_pdivisionid
           AND centrocostoid = p_pcentrocostoid
           AND departamentoid = p_pdepartamentoid
           AND lugarpagoid = p_plugarpagoid
           AND empresaid = p_pempresaid
    ) THEN
        -- 2) Intentar insertar
        BEGIN
            INSERT INTO division (
                divisionid,
                nombredivision,
                empresaid,
                direccion,
                comuna,
                ciudad,
                departamentoid,
                lugarpagoid,
                centrocostoid,
                fechacreacion,
                usuarioid
            ) VALUES (
                p_pdivisionid,
                p_pnombredivision,
                p_pempresaid,
                p_pdireccion,
                p_pcomuna,
                p_pciudad,
                p_pdepartamentoid,
                p_plugarpagoid,
                p_pcentrocostoid,
                now(),
                p_pusuarioid
            );
            var_mensaje := '';
            var_error   := 0;
        EXCEPTION WHEN OTHERS THEN
            var_mensaje := 'Error al agregar división: ' || SQLERRM;
            var_error   := 2;
        END;
    ELSE
        var_mensaje := 'La División ya existe';
        var_error   := 1;
    END IF;

    -- 3) DEBUG NOTICE
    IF p_debug <> 0 THEN
        RAISE NOTICE 'INSERT INTO division … VALUES(%, %, %, %, %, %, %, %, %, now(), %)',
            p_pdivisionid, p_pnombredivision, p_pempresaid, p_pdireccion,
            p_pcomuna, p_pciudad, p_pdepartamentoid, p_plugarpagoid, p_pcentrocostoid, p_pusuarioid;
    END IF;

    -- 4) Devolver resultado en cursor
    OPEN p_refcursor FOR
    SELECT var_mensaje AS "mensaje", var_error AS "error";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_division_agregar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_division_agregar(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    IS 'Agregar nueva división';
