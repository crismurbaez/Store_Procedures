-- FUNCTION: public.sp_documentosvigentes_listadoportiempo(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentosvigentes_listadoportiempo(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_documentosvigentes_listadoportiempo(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_piddocumento integer,
	p_pidtipodocumento integer,
	p_pidestadocontrato integer,
	p_pidtipofirma integer,
	p_pidproceso integer,
	p_pfirmante character varying,
	p_prutfirmante character varying,
	p_pempleado character varying,
	p_prutempleado character varying,
	p_pusuarioid character varying,
	p_pfichaid integer,
	p_fechainicio date,
	p_fechafin date,
	p_prutempresa character varying,--
	p_plugarpagoid character varying,
	p_pnombrelugarpago character varying,
	p_pdepartamentoid character varying,
	p_pnombredepartamento character varying,
	p_pcentrocosto character varying,
	p_pnombrecentrocosto character varying,
	p_pdivisionid character varying,
	p_pnombredivision character varying,--
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_offset integer := (p_pagina - 1) * p_decuantos::integer;
BEGIN
    -- Abrir cursor con paginación y alias correctos
    OPEN p_refcursor FOR
        SELECT
            C.iddocumento        AS "idDocumento",
            PL.idplantilla       AS "idPlantilla",
            PL.idtipodoc         AS "idTipoDoc",
            TD.nombretipodoc     AS "NombreTipoDoc",
            FD.fichaid           AS "fichaid",
            C.idproceso          AS "idProceso",
            P.descripcion        AS "Proceso",
            C.idestado           AS "idEstado",
            C.idestado           AS "idEstadoDocumento",  -- ← Agregar este alias que necesita PHP
            CE.descripcion       AS "Estado",
            C.idtipofirma        AS "idTipoFirma",
            FT.descripcion       AS "Firma",
            C.idwf               AS "idWF",
            WEP.diasmax          AS "DiasEstadoActual",
            CDV.lugarpagoid      AS "LugarPagoid",
            LP.nombrelugarpago   AS "nombrelugarpago",
            CDV.departamentoid   AS "departamentoid",
            DEP.nombredepartamento AS "nombredepartamento",
            to_char(C.fechacreacion, 'DD-MM-YYYY')    AS "FechaCreacion",
            to_char(C.fechaultimafirma, 'DD-MM-YYYY') AS "FechaUltimaFirma",
            ROW_NUMBER() OVER (ORDER BY C.iddocumento DESC) AS "RowNum",
            C.rutempresa         AS "RutEmpresa",
            E.razonsocial        AS "RazonSocial",
            CDV.rut              AS "Rut",
            PER.nombre           AS "nombre",
            PER.appaterno        AS "appaterno",
            PER.apmaterno        AS "apmaterno",
            (PER.nombre || ' ' || COALESCE(PER.appaterno,'') || ' ' || COALESCE(PER.apmaterno,'')) AS "NombreEmpleado",
            REP.personaid        AS "RutRep",
            REP.nombre           AS "nombre_rep",
            REP.appaterno        AS "appaterno_rep",
            REP.apmaterno        AS "apmaterno_rep",
            (REP.nombre || ' ' || COALESCE(REP.appaterno,'') || ' ' || COALESCE(REP.apmaterno,'')) AS "NombreFirmante",
            to_char(CDV.fechadocumento, 'DD-MM-YYYY')   AS "FechaDocumento"
        FROM contratos C
        JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento
        JOIN personas PER ON PER.personaid = CDV.rut
        JOIN empresas E ON E.rutempresa = C.rutempresa
        LEFT JOIN contratofirmantes CF ON CF.iddocumento = C.iddocumento AND C.idestado = CF.idestado
        LEFT JOIN personas REP ON REP.personaid = CF.rutfirmante
        LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid AND LP.empresaid = C.rutempresa
        LEFT JOIN departamentos DEP ON DEP.departamentoid = CDV.departamentoid AND DEP.lugarpagoid = CDV.lugarpagoid AND DEP.empresaid = C.rutempresa
        JOIN plantillas PL ON PL.idplantilla = C.idplantilla
        JOIN tipodocumentos TD ON PL.idtipodoc = TD.idtipodoc
        JOIN tiposdocumentosxperfil T ON PL.idplantilla = T.idtipodoc AND T.tipousuarioid = p_ptipousuarioid
        JOIN procesos P ON C.idproceso = P.idproceso
        JOIN contratosestados CE ON C.idestado = CE.idestado
        JOIN firmastipos FT ON C.idtipofirma = FT.idtipofirma
        LEFT JOIN workflowestadoprocesos WEP ON C.idwf = WEP.idworkflow AND C.idestado = WEP.idestadowf
        JOIN accesoxusuariodepartamentos ADV ON ADV.empresaid = C.rutempresa AND ADV.lugarpagoid = CDV.lugarpagoid AND ADV.departamentoid = CDV.departamentoid AND ADV.usuarioid = p_pusuarioid
        LEFT JOIN fichasdocumentos FD ON FD.documentoid = C.iddocumento AND FD.idfichaorigen = 2
        WHERE C.eliminado IS FALSE
          AND (p_pFirmante = '' OR REP.nombre ILIKE '%' || p_pFirmante || '%')
          AND (p_prutFirmante = '' OR CF.rutfirmante LIKE '%' || p_prutFirmante || '%')
          AND (p_pEmpleado = '' OR PER.nombre ILIKE '%' || p_pEmpleado || '%')
          AND (p_prutempleado = '' OR PER.personaid LIKE '%' || p_prutempleado || '%')
          AND (p_piddocumento = 0 OR C.iddocumento = p_piddocumento)
          AND (p_pidtipodocumento = 0 OR PL.idtipodoc = p_pidtipodocumento)
          AND (
            (p_pidestadocontrato > 0 AND C.idestado = p_pidestadocontrato)
            OR (p_pidestadocontrato = -1 AND C.idestado != 7)
            OR (p_pidestadocontrato = -2 AND C.idestado IN (1,4,7))
            OR (p_pidestadocontrato = 0 AND C.idestado IN (2,3,9,10,11))
          )
          AND (p_pidtipofirma = 0 OR C.idtipofirma = p_pidtipofirma)
          AND (p_pidproceso = 0 OR C.idproceso = p_pidproceso)
          AND (p_pfichaid <= 0 OR FD.fichaid = p_pfichaid)
          AND ((p_fechainicio IS NULL AND p_fechafin IS NULL)
               OR (p_fechafin IS NULL AND C.fechacreacion >= p_fechainicio)
               OR (p_fechafin IS NOT NULL AND C.fechacreacion BETWEEN p_fechainicio AND p_fechafin))
          AND (p_prutempresa = '' OR C.rutempresa = p_prutempresa)
          AND (p_plugarpagoid = '' OR CDV.lugarpagoid = p_plugarpagoid)
          AND (p_pnombrelugarpago = '' OR LP.nombrelugarpago ILIKE '%' || p_pnombrelugarpago || '%')
          AND (p_pdepartamentoid = '' OR CDV.departamentoid = p_pdepartamentoid)
          AND (p_pnombredepartamento = '' OR DEP.nombredepartamento ILIKE '%' || p_pnombredepartamento || '%')
        ORDER BY C.iddocumento DESC
        OFFSET v_offset LIMIT p_decuantos::integer;

    RETURN p_refcursor;
EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT 1 AS error, SQLERRM AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_documentosvigentes_listadoportiempo(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    OWNER TO postgres;
