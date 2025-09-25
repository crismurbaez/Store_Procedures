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
            D.divisionid AS "divisionid",
            D.nombredivision AS "nombredivision",
            D.centrocostoid AS "centrocostoid",
            D.departamentoid AS "departamentoid",
            D.lugarpagoid AS "lugarpagoid",
            ('''' || D.divisionid || '''') AS "div"
        FROM 
            division D
        WHERE 
            D.empresaid = pempresaid
            AND D.lugarpagoid = plugarpagoid
            AND D.departamentoid = pdepartamentoid
            AND D.centrocostoid = pcentrocostoid
        ORDER BY 
            D.nombredivision;
    
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
