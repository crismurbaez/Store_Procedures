-- FUNCTION: public.sp_division_obtener(refcursor, character varying, character varying, character varying, character varying, character varying)
-- Obtener una división específica

-- DROP FUNCTION IF EXISTS public.sp_division_obtener(refcursor, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_division_obtener(
	p_refcursor refcursor,
	p_pdivisionid character varying,
	p_pcentrocostoid character varying,
	p_pdepartamentoid character varying,
	p_plugarpagoid character varying,
	p_pempresaid character varying
)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    OPEN p_refcursor FOR
        SELECT 
            div.divisionid,
            div.nombredivision,
            div.empresaid,
            div.direccion,
            div.comuna,
            div.ciudad,
            div.departamentoid,
            dp.nombredepartamento,
            div.lugarpagoid,
            lp.nombrelugarpago,
            div.centrocostoid,
            cc.nombrecentrocosto,
            div.fechacreacion,
            div.fechamodificacion,
            div.usuarioid,
            div.usuarioidmodificacion,
            e.razonsocial AS nombreempresa
        FROM division div
        JOIN centroscosto cc ON div.centrocostoid = cc.centrocostoid 
                             AND div.departamentoid = cc.departamentoid 
                             AND div.lugarpagoid = cc.lugarpagoid 
                             AND div.empresaid = cc.empresaid
        JOIN departamentos dp ON div.departamentoid = dp.departamentoid 
                               AND div.lugarpagoid = dp.lugarpagoid 
                               AND div.empresaid = dp.empresaid
        JOIN lugarespago lp ON div.lugarpagoid = lp.lugarpagoid 
                            AND div.empresaid = lp.empresaid
        JOIN empresas e ON div.empresaid = e.rutempresa
        WHERE div.divisionid = p_pdivisionid
          AND div.centrocostoid = p_pcentrocostoid
          AND div.departamentoid = p_pdepartamentoid
          AND div.lugarpagoid = p_plugarpagoid
          AND div.empresaid = p_pempresaid;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_division_obtener(refcursor, character varying, character varying, character varying, character varying, character varying)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_division_obtener(refcursor, character varying, character varying, character varying, character varying, character varying)
    IS 'Obtener una división específica con información completa';
