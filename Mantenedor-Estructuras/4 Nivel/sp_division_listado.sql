-- FUNCTION: public.sp_division_listado(refcursor, character varying, character varying, character varying, character varying)
-- Listado simple de divisiones por empresa, lugar de pago, departamento y centro de costo

-- DROP FUNCTION IF EXISTS public.sp_division_listado(refcursor, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_division_listado(
	p_refcursor refcursor,
	pempresaid character varying,
	plugarpagoid character varying,
	pdepartamentoid character varying,
	pcentrocostoid character varying
)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    OPEN p_refcursor FOR
        SELECT 
            d.divisionid AS "divisionid",
            d.nombredivision AS "nombredivision",
            d.centrocostoid AS "centrocostoid",
            d.departamentoid AS "departamentoid",
            d.lugarpagoid AS "lugarpagoid",
            ('''' || d.divisionid || '''') AS "cc"
        FROM 
            division d
        WHERE 
            d.empresaid = pempresaid
            AND d.lugarpagoid = plugarpagoid
            AND d.departamentoid = pdepartamentoid
            AND d.centrocostoid = pcentrocostoid
        ORDER BY 
            d.nombredivision;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_division_listado(refcursor, character varying, character varying, character varying, character varying)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_division_listado(refcursor, character varying, character varying, character varying, character varying)
    IS 'Listado simple de divisiones por empresa, lugar de pago, departamento y centro de costo';
