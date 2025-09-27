-- FUNCTION: public.sp_division_obtener2(refcursor, character varying, character varying, character varying, character varying, character varying)
-- Obtener una división específica

-- DROP FUNCTION IF EXISTS public.sp_division_obtener2(refcursor, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_division_obtener2(
	p_refcursor refcursor,
	p_pempresaid character varying,
	p_plugarpagoid character varying,
	p_pdepartamentoid character varying,
	p_pcentrocostoid character varying,
	p_pdivisionid character varying
)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    OPEN p_refcursor FOR
        SELECT 
            d.divisionid as divisionid,
			d.divisionid as "idDivision",
            d.nombredivision,
            d.empresaid as "empresaid",
			d.empresaid as "RutEmpresa",
			d.empresaid as "RazonSocial",
            d.direccion,
            d.comuna,
            d.ciudad,
            d.departamentoid,
            dp.nombredepartamento,
            d.lugarpagoid,
            lp.nombrelugarpago,
            d.centrocostoid,
            cc.nombrecentrocosto,
            d.fechacreacion,
            d.fechamodificacion,
            d.usuarioid,
            d.usuarioidmodificacion,
            e.razonsocial AS nombreempresa
        FROM division d
        JOIN centroscosto cc ON d.centrocostoid = cc.centrocostoid 
                             AND d.departamentoid = cc.departamentoid 
                             AND d.lugarpagoid = cc.lugarpagoid 
                             AND d.empresaid = cc.empresaid
        JOIN departamentos dp ON d.departamentoid = dp.departamentoid 
                               AND d.lugarpagoid = dp.lugarpagoid 
                               AND d.empresaid = dp.empresaid
        JOIN lugarespago lp ON d.lugarpagoid = lp.lugarpagoid 
                            AND d.empresaid = lp.empresaid
        JOIN empresas e ON d.empresaid = e.rutempresa
        WHERE d.divisionid = p_pdivisionid
          AND d.centrocostoid = p_pcentrocostoid
          AND d.departamentoid = p_pdepartamentoid
          AND d.lugarpagoid = p_plugarpagoid
          AND d.empresaid = p_pempresaid;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_division_obtener2(refcursor, character varying, character varying, character varying, character varying, character varying)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_division_obtener2(refcursor, character varying, character varying, character varying, character varying, character varying)
    IS 'Obtener una División específica con información completa';

