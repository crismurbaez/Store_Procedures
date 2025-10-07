-- FUNCTION: public.sp_contratodatosvariables_agregar(refcursor, integer, text, text, text, text, text, text, text, integer, text, text, text, text, text, integer, text, text, text, text, text, integer, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text)

-- DROP FUNCTION IF EXISTS public.sp_contratodatosvariables_agregar(refcursor, integer, text, text, text, text, text, text, text, integer, text, text, text, text, text, integer, text, text, text, text, text, integer, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION public.sp_contratodatosvariables_agregar(
	p_refcursor refcursor,
	p_piddocumento integer,
	p_rut text,
	p_lugarpagoid text,
	p_departamentoid text,
	p_centrocosto text,
	p_divisionid text,
	p_quintonivelid text,
	p_fechadocumento text,
	p_afp text,
	p_banco text,
	p_cargo text,
	p_colacion integer,
	p_fechaingreso text,
	p_fechainicio text,
	p_fechatermino text,
	p_horas text,
	p_jornada text,
	p_movilizacion integer,
	p_nombrecontactoemergencia text,
	p_tipocuenta text,
	p_nrocuenta text,
	p_salud text,
	p_sueldobase text,
	p_bonotelefono integer,
	p_telefonocontactoemergencia text,
	p_texto1 text,
	p_texto2 text,
	p_texto3 text,
	p_texto4 text,
	p_texto5 text,
	p_texto6 text,
	p_texto7 text,
	p_texto8 text,
	p_texto9 text,
	p_texto10 text,
	p_texto11 text,
	p_texto12 text,
	p_texto13 text,
	p_texto14 text,
	p_texto15 text,
	p_texto16 text,
	p_texto17 text,
	p_texto18 text,
	p_texto19 text,
	p_texto20 text,
	p_areafuncional text)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_ref ALIAS FOR p_refcursor;
    v_error integer := 0;
    v_mensaje text := '';
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM contratodatosvariables WHERE iddocumento = p_piddocumento
    ) THEN
        INSERT INTO contratodatosvariables (
            iddocumento, rut, lugarpagoid, departamentoid,
            centrocosto, divisionid, quintonivelid,
            fechadocumento, afp, banco, cargo, colacion,
            fechaingreso, fechainicio, fechatermino,
            horas, jornada, movilizacion, nombrecontactoemergencia,
            tipocuenta, nrocuenta, salud, sueldobase,
            bonotelefono, telefonocontactoemergencia,
            texto1, texto2, texto3, texto4, texto5,
            texto6, texto7, texto8, texto9, texto10,
            texto11, texto12, texto13, texto14, texto15,
            texto16, texto17, texto18, texto19, texto20,
            areafuncional
        )
        VALUES (
            p_piddocumento, p_rut, p_lugarpagoid, p_departamentoid,
            p_centrocosto, p_divisionid, p_quintonivelid,
            NULLIF(p_fechadocumento, '')::date, p_afp, p_banco, p_cargo, p_colacion,
            NULLIF(p_fechaingreso, '')::date,
            NULLIF(p_fechainicio, '')::date,
            NULLIF(p_fechatermino, '')::date,
            p_horas, p_jornada, p_movilizacion, p_nombrecontactoemergencia,
            p_tipocuenta, p_nrocuenta, p_salud, NULLIF(p_sueldobase, '')::integer,
            p_bonotelefono, p_telefonocontactoemergencia,
            p_texto1, p_texto2, p_texto3, p_texto4, p_texto5,
            p_texto6, p_texto7, p_texto8, p_texto9, p_texto10,
            p_texto11, p_texto12, p_texto13, p_texto14, p_texto15,
            p_texto16, p_texto17, p_texto18, p_texto19, p_texto20,
            p_areafuncional
        );
    ELSE
        UPDATE contratodatosvariables SET
            rut = p_rut,
            lugarpagoid = p_lugarpagoid,
            departamentoid = p_departamentoid,
            centrocosto = p_centrocosto,
            divisionid = p_divisionid,
            quintonivelid = p_quintonivelid,
            fechadocumento = NULLIF(p_fechadocumento, '')::date,
            afp = p_afp,
            banco = p_banco,
            cargo = p_cargo,
            colacion = p_colacion,
            fechaingreso = NULLIF(p_fechaingreso, '')::date,
            fechainicio = NULLIF(p_fechainicio, '')::date,
            fechatermino = NULLIF(p_fechatermino, '')::date,
            horas = p_horas,
            jornada = p_jornada,
            movilizacion = p_movilizacion,
            nombrecontactoemergencia = p_nombrecontactoemergencia,
            tipocuenta = p_tipocuenta,
            nrocuenta = p_nrocuenta,
            salud = p_salud,
            sueldobase = NULLIF(p_sueldobase, '')::integer,
            bonotelefono = p_bonotelefono,
            telefonocontactoemergencia = p_telefonocontactoemergencia,
            texto1 = p_texto1, texto2 = p_texto2, texto3 = p_texto3,
            texto4 = p_texto4, texto5 = p_texto5, texto6 = p_texto6,
            texto7 = p_texto7, texto8 = p_texto8, texto9 = p_texto9,
            texto10 = p_texto10, texto11 = p_texto11, texto12 = p_texto12,
            texto13 = p_texto13, texto14 = p_texto14, texto15 = p_texto15,
            texto16 = p_texto16, texto17 = p_texto17, texto18 = p_texto18,
            texto19 = p_texto19, texto20 = p_texto20,
            areafuncional = p_areafuncional
        WHERE iddocumento = p_piddocumento;
    END IF;

    OPEN v_ref FOR
    SELECT v_error AS "error", v_mensaje AS "mensaje";

    RETURN v_ref;

EXCEPTION WHEN OTHERS THEN
    OPEN v_ref FOR SELECT 1 AS "error", SQLERRM AS "mensaje";
    RETURN v_ref;
END;
$BODY$;

ALTER FUNCTION public.sp_contratodatosvariables_agregar(refcursor, integer, text, text, text, text, text, text, text, integer, text, text, text, text, text, integer, text, text, text, text, text, integer, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text)
    OWNER TO postgres;
