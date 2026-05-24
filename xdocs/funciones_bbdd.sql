-- Version: 20/05/2026

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cdx_borra_campaign`( IN v_idApp 			BIGINT  
																, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
																, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																, IN  v_idCampaign	 	bigint
																)
BEGIN
DECLARE nExiste			int;
DECLARE dFecha			datetime;
DECLARE nSaldo 			DECIMAL(11,2);
DECLARE cDescripcion	VARCHAR(250);
DECLARE nIdDir			BIGINT;
DECLARE nidMsj			BIGINT;
DECLARE nIdCnt			BIGINT;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cdx_borra_campaign';
-- DECLARE ex_validaciones CONDITION FOR SQLSTATE '45001';
DECLARE ex_controladas	CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de CURSORES
-- -----------------------------------------------------------------------------------------------------
DECLARE bFinCursor INT DEFAULT FALSE;

DECLARE cur1 CURSOR FOR 
	Select id				as nidMsj
		  ,id_contenido 	as nIdCnt
      from cdx_campaigns_cnt_mensajes 
	 where id_campaign = v_idCampaign;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET bFinCursor = TRUE;

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = errorText;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
/*DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
		ROLLBACK;
	End;    
*/
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
		SET cDonde = 'Inicio';
        Select count(*) Into nExiste from cdx_campaigns where id = v_idCampaign;
        IF nExiste = 0 then
			SET v_retTxt = concat('No existe la campaña ', v_idCampaign);
			SIGNAL ex_controladas;
        END IF;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
	SET cDonde = 'Borramos cdx_campaigns_adicionales: ';
	delete from cdx_campaigns_adicionales where id_campaign = v_idCampaign;
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');

	-- Borrando contenido de los mensajes:
	SET cDonde = 'Apertura cursor 1';
	SET v_retTxt = 'Apertura cursor 1';
    OPEN cur1;
	bucle:LOOP 
		SET bFinCursor = false
		  , cDonde 	   = 'leemos cursor 1';
		SET v_retTxt = 'Lectura cursor 1';
		FETCH cur1  into nidMsj, nIdCnt;
        IF bFinCursor THEN
			LEAVE bucle;
        END IF;

		CALL cnt_borra( v_idApp, v_user, v_retNum, v_retTxt, nIdCnt);
		IF v_retNum != 0 THEN
				SET v_retTxt = concat('Error al borrar contenido ', nIdCnt, ' del mensaje', nidMsj);
				SIGNAL ex_controladas;
		END IF;
	END LOOP;
    CLOSE cur1;    
                                                    
	SET cDonde = concat(cDonde, 'Borramos cdx_campaigns_cnt_mensajes: ');
	delete from cdx_campaigns_cnt_mensajes where id_campaign = v_idCampaign;
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');
    
	-- -----------------------------------------------------
	-- -----------------------------------------------------
	SET cDonde = concat(cDonde, 'Borramos cdx_archivos: ');
	delete from cdx_archivos where id_campaign = v_idCampaign;
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');

	-- ----------------------------------------------------------------------------------------------------
    -- Peligro, estamos desactivando las FK
    -- Lo hago porque es circular, primero habría que poner a null uno de los dos y eso es un update mas....
    -- y SAFE MODE por borrar por ID en tablas de precodigos
    -- ----------------------------------------------------------------------------------------------------
	SET FOREIGN_KEY_CHECKS = 0;
    SET sql_safe_updates = 0;
	-- ----------------------------------------------------------------------------------------------------
	-- ----------------------------------------------------
	-- PRECODIGOS -----------------------------------------
	SET cDonde = concat(cDonde, 'Borramos cdx_precodigos_envios: ');
	delete from cdx_precodigos_envios where id_precodigo in (select id from cdx_precodigos where id_campaign = v_idCampaign);
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');
    
	SET cDonde = concat(cDonde, 'Borramos cdx_precodigos_estado: ');
	delete from cdx_precodigos_estado where id_precodigo in (select id from cdx_precodigos where id_campaign = v_idCampaign);
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');

	SET cDonde = concat(cDonde, 'Borramos cdx_precodigos: ');
	delete from cdx_precodigos where id_campaign = v_idCampaign;
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');
    
	SET cDonde = concat(cDonde, 'Borramos exp_campaigns_categorias: ');
	delete from exp_campaigns_categorias where id_campaign = v_idCampaign;
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');

	SET cDonde = 'Borramos cdx_etiquetas_morphs: ';
    delete from cdx_etiqueta_morphs 
	 where model_id = v_idCampaign
      and model_type = 'HangarXxi\Madre\Models\...\LoQueSea';
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');

	-- ----------------------------------------------------
	-- CANJES ---------------------------------------------
	SET cDonde = concat(cDonde, 'Borramos cnj_ficheros: ');
	delete from cnj_ficheros where id_canje in (select id from cnj_canjes where id_campaign = v_idCampaign);
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');

	SET cDonde = concat(cDonde, 'Borramos cnj_campos: ');
	delete from cnj_campos where id_canje in (select id from cnj_canjes where id_campaign = v_idCampaign);
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');

	SET cDonde = concat(cDonde, 'Borramos cnj_canjes: ');
	delete from cnj_canjes where id_campaign = v_idCampaign;
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');
    
    -- CAMPAÑA --------------------------------------------
	-- ----------------------------------------------------    
	SET cDonde = concat(cDonde, 'Borramos cdx_campaigns: ');
	delete from cdx_campaigns where id = v_idCampaign;
	SET cDonde = concat(cDonde, ROW_COUNT(), '\n');
    
	-- ----------------------------------------------------------------------------------------------------
	SET sql_safe_updates = 1;
	SET FOREIGN_KEY_CHECKS = 1;
	-- ----------------------------------------------------------------------------------------------------
    -- FIN Peligro
    -- ----------------------------------------------------------------------------------------------------

	-- SET cDonde = concat(cDonde, 'No se borran los ficheros físicos de consentimiento, carga de precodigos de la campaña, ficheros de imagen o fiscales de los canjes');
    SET v_retNum  = 0;
    SET v_retTxt =  cDonde;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cdx_canje`( IN v_idApp			 	 BIGINT  
															, IN v_user 			 VARCHAR(45)         -- Usuario que lanza el procedimiento
															, INOUT v_retNum 		 INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt 		 VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                                
															, IN  v_precodigo		 VARCHAR(25) 
															, INOUT v_idParticipante BIGINT 
															, IN  v_id_frontal		 BIGINT 
															, IN  v_id_campaign		 BIGINT 
															, IN  v_id_prod			 BIGINT 
															, IN  v_id_cat			 BIGINT 
                                                            
															, IN  v_unidades	 	 INT 
															, IN  v_puntos		 	 INT 
															, IN  v_fec_canje		 VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
															, IN  v_links_vouchers	 VARCHAR(4000)
                                                            
                                                            , IN  v_json_datos		 VARCHAR(4000)     -- Datos de campos variables
															, IN  v_json_fichero	 VARCHAR(4000)     -- Lista de ficheros asociados al canje
                                                            
															, IN  v_fiscales		 VARCHAR(1)   	-- S o N, uno de los dos obligatorios y si es "S" debe llevar los datos fiscaless
															, IN  v_fiscal_nombre	 VARCHAR(200)   -- o razon social
															, IN  v_fiscal_apell	 VARCHAR(200)	
															, IN  v_fiscal_dni		 VARCHAR(19)     
															, IN  v_fiscal_telf		 VARCHAR(19)     
                                                            , INOUT v_idFiscalDir	 BIGINT       -- si viene este campo no se tiene en cuenta la dirección
															, IN  v_fiscal_dir1		 VARCHAR(200)     
															, IN  v_fiscal_id_prov	 BIGINT     
															, IN  v_fiscal_CP		 VARCHAR(10)     
															, IN  v_fiscal_localidad VARCHAR(75)     

															, OUT v_id   		BIGINT          -- ID de la operación creada
															)
BEGIN
DECLARE nExiste			 INT;
DECLARE dFechaCanje		 DATETIME;
DECLARE dEnviado		 DATETIME default null;

DECLARE nFrontal		 BIGINT default v_id_frontal;
DECLARE nCampaign		 BIGINT;
DECLARE nParticipante	 BIGINT;
DECLARE nCatalogo	 	 BIGINT;
DECLARE xURL			 VARCHAR(200);

DECLARE dInicioCampa	 DATETIME;
DECLARE dFinCampa		 DATETIME;
DECLARE cPremiodir		 VARCHAR(1);
DECLARE nStatus		 	 INT;
DECLARE nMaxCanjes		 INT;
DECLARE cTipos			 VARCHAR(500);
DECLARE cTieneTicket	 CHAR(1);
DECLARE nLimiteFiscal	 INT default 400;
DECLARE xLabel		 	 VARCHAR(500);
DECLARE xTooltip		 VARCHAR(500);

DECLARE cNombre			 VARCHAR(100);
DECLARE cApellidos		 VARCHAR(100);
DECLARE cNombreCompleto	 VARCHAR(200);
DECLARE cEmail			 VARCHAR(200);
DECLARE cTelf			 VARCHAR(15);
DECLARE ndDir			 BIGINT;

DECLARE cDir1		 	 VARCHAR(200);
DECLARE cNumero		 	 VARCHAR(10);
DECLARE cDir2		 	 VARCHAR(200);
DECLARE nIdProv		 	 BIGINT;
DECLARE cCP			 	 VARCHAR(10);
DECLARE cLocalidad 	 	 VARCHAR(75);
DECLARE cPais	 	 	 VARCHAR(2);

DECLARE cEstado			 VARCHAR(1);
DECLARE nIdMovCanje		 BIGINT;	
DECLARE nSaldo			 INT;
DECLARE cFiscalNombre	 VARCHAR(200);
DECLARE cFiscalApellidos VARCHAR(60);
DECLARE cFiscalDni		 VARCHAR(20);
DECLARE cFiscalTelefono	 VARCHAR(20);
DECLARE nFiscalIdDir	 BIGINT;
DECLARE cComentario		 VARCHAR(4000);

DECLARE nIdPrecodigo	 BIGINT;
DECLARE cPremiado		 CHAR(1);
DECLARE cEstadoPreCod 	 CHAR(1);
DECLARE fCaducidad		 DATETIME;
DECLARE xCanje		 	 DATETIME;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cdx_canje';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';
-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;

		SET v_retNum = null;
		SET v_retTxt = null;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
            
		SET v_retNum = -2;
		Call hxxi_crea_log(v_idApp , 'A', '1', v_user, errorNum, errorText, errorMySql, concat(cDonde, '. MiError'),  v_retNum, v_retTxt); 
	End;    
  
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	set cDonde = 'Comprobaciones0';
	IF v_precodigo is null Then
		SELECT g_texto('No_ha_llegado_Precódigo.', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	IF ifnull(v_id_frontal,0) = 0 Then
        SELECT g_texto('No_ha_llegado_id_frontal', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	IF ifnull(v_id_campaign,0) = 0 Then
        SELECT g_texto('No_ha_llegado_id_campaign', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	IF IFNULL(v_unidades, 0) <= 0 is null Then
        SELECT g_texto('No_han_llegado_unidades', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	IF IFNULL(v_puntos,0) <= 0 is null Then
        SELECT g_texto('No_han_llegado_puntos.', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

    -- comprobamos formato de la fecha
    Select g_fecha_ok(v_fec_canje , '%Y-%m-%d %H:%i:%s', 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
	ELSE 
		select STR_TO_DATE(v_fec_canje, '%Y-%m-%d %H:%i:%s') into dFechaCanje;
    END IF;
    
-- IF v_json_datos is null Then
--        set v_retTxt = 'No ha llegado v_json_datos';
-- 	SIGNAL ex_controladas;
-- END IF;
    
	IF ifnull(upper(v_fiscales),"_") not in ("S","N") Then
		SELECT g_texto('Se_ha_de_indicar_si_"S"_o_"N"_lleva_datos_fiscales_(v_fiscales)', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	set cDonde = 'Comprobaciones70';
	IF upper(v_fiscales) = "S" Then
		set cDonde = 'Comprobaciones71';
		IF v_fiscal_nombre is null Then
			SELECT g_texto('No_ha_llegado_v_fiscal_nombre_o_Razón_Social', v_idApp) INTO v_retTxt;
			SIGNAL ex_controladas;
		END IF;
		set cDonde = 'Comprobaciones72';
		IF v_fiscal_dni is null Then
			SELECT g_texto('No_ha_llegado_documento_fiscal', v_idApp) INTO v_retTxt;
			SIGNAL ex_controladas;
		END IF;
		set cDonde = 'Comprobaciones73';
		IF v_fiscal_dir1 is null and IFNULL(v_idFiscalDir,0) = 0 Then
			SELECT g_texto('No_ha_llegado_dirección', v_idApp) INTO v_retTxt;
			SIGNAL ex_controladas;
		END IF;
	END IF;
	-- -----------------------------------------------------------------------------------------------------
    -- Desgranamos los campos de los variables que son obligatorios
	-- -----------------------------------------------------------------------------------------------------
	set cDonde = 'Comprobaciones80'; Select g_cdx_extrae_campo("nombre", v_json_datos) into cNombre;
	set cDonde = 'Comprobaciones80a';Select g_cdx_extrae_campo("apellidos", v_json_datos) into cApellidos;
	set cDonde = 'Comprobaciones81'; Select g_cdx_extrae_campo("email", v_json_datos) into cEmail;
	set cDonde = 'Comprobaciones82'; Select g_cdx_extrae_campo("telefono", v_json_datos) into cTelf;
	set cDonde = 'Comprobaciones83'; Select g_cdx_extrae_campo("idDir", v_json_datos) into ndDir;
    
    set cNombreCompleto = concat(cNombre, ifnull(cApellidos,''));
    
	IF ndDir is NULL THEN
		set cDonde = 'Comprobaciones84'; Select g_cdx_extrae_campo("calle", v_json_datos) into cDir1;
		set cDonde = 'Comprobaciones85'; Select g_cdx_extrae_campo("numero", v_json_datos) into cNumero;
		set cDonde = 'Comprobaciones86'; Select g_cdx_extrae_campo("dir_adicionales", v_json_datos) into cDir2;
		set cDonde = 'Comprobaciones87'; Select g_cdx_extrae_campo("cp", v_json_datos) into cCP;
		set cDonde = 'Comprobaciones88'; Select g_cdx_extrae_campo("localidad", v_json_datos) into cLocalidad;
		set cDonde = 'Comprobaciones89'; Select g_cdx_extrae_campo("provincia", v_json_datos) into nIdProv;
		set cDonde = 'Comprobaciones90'; Select g_cdx_extrae_campo("pais", v_json_datos) into cPais;
	ELSE		
		SELECT	direccion1,	numero, 	direccion2,	cp,		id_provincia,	'ES'
		  INTO	cDir1, 		cNumero,	cDir2,		cCP,	nIdProv,		cPais
		  FROM  dir_direcciones
         WHERE  id = ndDir;
	END IF;
    
	set cDonde = 'Comprobaciones91'; 
	IF ifnull(v_idParticipante,0) = 0 Then
        CALL hxxi_crea_participante (v_idApp,	v_user,		v_retNum,	v_retTxt,	v_idParticipante
									,cNombre,	cApellidos,	cEmail,		cEmail,		cTelf
                                    ,concat(cDir1, ' ', cNumero, ' ', cDir2), 	cCP,	nIdProv,	cPais);
		IF v_retNum < 0 THEN
			SIGNAL ex_controladas;
        END IF;
	ELSE
		Select count(id) into nExiste from hxxi_participantes where id = v_idParticipante;
		IF nExiste = 0 Then
   			SELECT g_texto('El_participante_no_Existe', v_idApp) INTO v_retTxt;
			SIGNAL ex_controladas;
		END IF;
    END IF;

	-- -----------------------------------------------------------------------------------------------------

	set cDonde = 'Validando Precodigo'; 
	CALL cdx_valida_precodigo(v_idApp, v_user, v_retNum, v_retTxt, 'CDX', v_precodigo, dFechaCanje, xURL, nFrontal ,nCatalogo, nCampaign, xCanje, nParticipante, nIdPrecodigo);
	IF v_retNum != 0  THEN 
		SIGNAL ex_controladas;
	END IF;
	IF v_id_frontal != nFrontal THEN
        SELECT g_texto('Error_Campaña/Frontal', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;
	-- -----------------------------------------------------------------------------------------------------
	-- -----------------------------------------------------------------------------------------------------
    -- 1--> Realizado: El participante ha hecho el pedido y hay que enviarlo, no tiene confirmación.
    -- 2--> Pendiente confirmar: El cliente ha hecho el pedido, pero es un pedido pendiente de confirmación.
    -- 3--> Confirmado: El cliente ha hecho un pedido que necesita confirmación y un gestor lo ha confirmado.
    -- 4--> Rechazado: El cliente ha hecho el pedido que necesita confirmación y un gestor lo ha anulado (aunque podría ser un proceso el que lo ha rechazado).
    -- 5-->Anulado: Un pedido ya creado se ha anulado (por el motivo que sea).
    -- 6--> Enviado: en pedidos realizados o confirmados. El pedido se ha enviado. En los digitales es cuando se envía el email o sms, en los físicos es cuando se descarga el fichero para el proveedor logístico.
	-- -----------------------------------------------------------------------------------------------------
    IF cTieneTicket = 'S' OR cPremiodir = 'S' THEN
		SET cEstado			= "2"; -- Pendiente confirmar: El cliente ha hecho el pedido, pero es un pedido pendiente de confirmación.
    ELSE
        IF true THEN
			SET cEstado		= "1"; -- Realizado: El participante ha hecho el pedido y hay que enviarlo, no tiene confirmación.
            SET dEnviado	= dFechaCanje;	 
        ELSE
			SET cEstado		= "6"; -- Enviado: en pedidos realizados o confirmados. El pedido se ha enviado. En los digitales es cuando se envía el email o sms, en los físicos es cuando se descarga el fichero para el proveedor logístico.
        END IF;
    END IF;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
	-- -----------------------------------------------------------------------------------------------------
    SET v_retTxt = 'OK';
    SET v_retNum = 0;
   
	-- -----------------------------------------------------------------------------------------------------
    -- Creamos el movimiento de canje, que ya de por sí hacae VALIDACIONES
	-- -----------------------------------------------------------------------------------------------------
	set cDonde = 'Creando canje completo';
	Call cnj_crea_Completo	( v_idApp			, v_user         , v_retNum     	, v_retTxt		
							, v_idParticipante	, v_id_cat  	 , v_id_prod		, v_id_campaign	  , v_links_vouchers 
                            , v_unidades		, v_puntos       , v_fec_canje  	, null			  , dEnviado
                            , "CDX"				, v_json_datos   , v_json_fichero	, cNombreCompleto , cEmail		, cTelf       
                            , ndDir				, cDir1	 	 	 , cNumero			, cDir2			  , cCP		  	, nIdProv		, cLocalidad , cPais
                            , v_fiscal_nombre	, v_fiscal_apell , v_fiscal_dni 	, v_fiscal_telf 	
                            , v_idFiscalDir		, v_fiscal_dir1  , v_fiscal_CP  	, v_fiscal_id_prov, v_fiscal_localidad 
                            , cEstado			, v_id			 , nIdMovCanje  	, nSaldo		  , cTipos);

	IF v_retNum != 0  THEN 
		SIGNAL ex_controladas;
	END IF;
	-- -------------------------------------------------------------------------------------------------------
    -- Actualizamos el PRECODIGO
	-- -------------------------------------------------------------------------------------------------------
	UPDATE cdx_precodigos  
       SET id_participante	= v_idParticipante
		  ,id_canje			= v_id
          ,status			= "1" -- '0 --> sin enviar (ya sea a un fichero o por emal/sms); 1 --> Activo (se ha enviado); 2 --> Inactivo (se ha anulado, pero siempre antes de canjear)',    
          ,modified_by		= v_user
	 WHERE id = nIdPrecodigo;

	-- -------------------------------------------------------------------------------------------------------
    -- Hacemos una comprobación final, una vez creado el canje y sabiendo que ficheros se han cargado y campos
    -- SET('DNI1', 'DNI2', 'CONS', 'TICKET', 'OTRO')
	-- -------------------------------------------------------------------------------------------------------
	IF cTieneTicket = 'S' AND INSTR(cTipos, 'TICKET') <= 0 THEN
		SELECT g_texto(concat(v_retTxt,' Es_obligatorio_adjuntar_un_ticket'), v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
    END IF;
    CALL hxxi_configuracion( v_idApp , v_user , v_retNum , v_retTxt , NULL , 'general', 'minimo_monto_verificar' , nLimiteFiscal , xLabel , xTooltip); 
	IF v_retNum != 0  THEN 
		SET v_retNum = 0;
		SET v_retTxt = '';
		SET nLimiteFiscal = 300;
	END IF;

	IF (v_puntos*v_unidades) > nLimiteFiscal AND (INSTR(cTipos, 'DNI1') <= 0 OR INSTR(cTipos, 'DNI2') <= 0 OR INSTR(cTipos, 'CONS') <= 0) THEN
		SELECT g_texto(concat(v_retTxt,' Es_obligatorio_adjuntar_DNI_parte_delantera_y_trasera_y_Consentimiento'), v_idApp) INTO v_retTxt;
        SIGNAL ex_controladas;
    END IF;

    
	SET v_retNum = cEstado;
	SELECT g_texto('Canje_realizado_con_éxito.', v_idApp) INTO v_retTxt;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cdx_valida_campos_adic`( IN v_idApp 		BIGINT  
																, IN v_user 		VARCHAR(45)    -- Usuario que lanza el procedimiento
																, INOUT v_retNum 	INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																, INOUT v_retTxt 	VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																, IN  v_idCampaign	BIGINT		   
																, IN  v_campo		VARCHAR(100)
																, IN  v_tipo		VARCHAR(1)
                                                                , IN  v_TipoProd	CHAR(1)
                                                                , OUT v_idCampo		BIGINT
																)
BEGIN
DECLARE nExiste		INT;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cdx_valida_campos_adic';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	IF v_idCampaign IS NULL OR v_campo  IS NULL OR v_tipo IS NULL THEN    
        set v_retTxt = 'Error de parámetros';
		SIGNAL ex_controladas;
	END IF;

	SELECT id, count(id) INTO v_idCampo, nExiste 
      FROM cdx_campaigns_adicionales
	 WHERE id_campaign = v_idCampaign
	   AND upper(etiqueta)    COLLATE utf8mb4_general_ci = upper(v_campo)		
       AND upper(tipo_basico) COLLATE utf8mb4_general_ci = upper(v_tipo)
       AND producto           COLLATE utf8mb4_general_ci = v_TipoProd
	 GROUP BY id;

    IF ifnull(nExiste,0) = 0 Then
		set v_retTxt = CONCAT('El campo "', v_campo,'-', v_tipo, '" No es válido para la campaña ', v_idCampaign);
		SIGNAL ex_controladas;
    END IF;   
   
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cdx_valida_precodigo`( IN v_idApp 				BIGINT  
																	  , IN v_user 				VARCHAR(45)         -- Usuario que lanza el procedimiento
																	  , INOUT v_retNum 			INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado. 2 --> El precodigo ya ha sido canjeado
																	  , INOUT v_retTxt 			VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																	  , IN  v_modulo			VARCHAR(5)
																	  , IN  v_precodigo			VARCHAR(30)
																	  , IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																	  , IN  v_url				VARCHAR(400) 	-- LLeva URL o ....
																	  , INOUT v_idFrontal		BIGINT			-- ... lleva IdFrontal
																	  , OUT v_idCatalogo		BIGINT
																	  , OUT v_idCampaign		BIGINT
                                                                      , OUT v_idCanje			BIGINT
																	  , OUT v_idParticipante	BIGINT
                                                                      , OUT v_idPrecodigo		BIGINT
																	  )
BEGIN
DECLARE nExiste		int;
DECLARE dFecha		datetime;

DECLARE cPremiado		CHAR(1);
DECLARE cEstado			CHAR(1);
DECLARE dCaducidad		datetime;
DECLARE nMaxCanjes		BIGINT;
      
-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cdx_valida_precodigo';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;

		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
            
		SET v_retNum = -2;
		Call hxxi_crea_log(v_idApp , 'A', '1', v_user, errorNum, errorText, errorMySql, concat(cDonde, '. MiError2'),  v_retNum, v_retTxt); 
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	-- -----------------------------------------------------------------------------------------------------
    -- Validaciones
	-- -----------------------------------------------------------------------------------------------------
	IF v_precodigo IS NULL THEN
        set v_retTxt = 'No ha llegado PRECODIGO';
		SIGNAL ex_controladas;
	END IF;
	IF v_url IS NULL and IFNULL(v_idFrontal,0) = 0 THEN
        set v_retTxt = 'Debe llegar ULR o Frontal';
		SIGNAL ex_controladas;
	END IF;
    -- comprobamos formato de la fecha
    Select g_fecha_ok(v_fecha , '%Y-%m-%d %H:%i:%s', 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
    END IF;
    
	-- -----------------------------------------------------------------------------------------------------
    -- Búsquedas auxiliares
	-- -----------------------------------------------------------------------------------------------------
	SET v_retTxt = 'OK';
	SET v_retNum = 0;
    
    IF IFNULL(v_idFrontal,0) = 0 Then
		SET cDonde = "Validando url";
		SELECT count(*) INTO nExiste FROM cdx_frontales 
         where id_app = v_idApp 
           and upper(dominio) COLLATE utf8mb4_general_ci = upper(v_url) 
           and modulo COLLATE utf8mb4_general_ci = v_modulo;
        IF nExiste = 1 THEN
			SET cDonde = "REcogiendo frontal";
			SELECT id INTO v_idFrontal FROM cdx_frontales 
			 where id_app = v_idApp 
			   and upper(dominio) COLLATE utf8mb4_general_ci = upper(v_url) 
			   and modulo COLLATE utf8mb4_general_ci = v_modulo;
		ELSE
			SET v_retTxt = 'No se encuentra un frontal para esa App/dominio/módulo';
			SIGNAL ex_controladas;
		END IF;
    END IF;
    
	-- -----------------------------------------------------------------------------------------------------
    -- Busqueda PRECODIGO y datos de salida
	-- -----------------------------------------------------------------------------------------------------
	SET cDonde = "Validando precodigo";
    SELECT id, 				id_campaign,  id_participante,  premiado,  status,  id_canje,	caducidad
	  INTO v_idPrecodigo,	v_idCampaign, v_idParticipante, cPremiado, cEstado, v_idCanje, dCaducidad	
      FROM cdx_precodigos
     WHERE precodigo COLLATE utf8mb4_general_ci = v_precodigo
       AND id_frontal = v_idFrontal;
	IF v_idPrecodigo IS NULL THEN
		-- SET v_retTxt = concat('Precódigo (', v_precodigo, ') no válido para el frontal ', v_idFrontal);
        SET v_retTxt = concat('Precódigo "', v_precodigo, '" no válido para el frontal');
		SIGNAL ex_controladas;
	ELSE
		IF cPremiado = 'N' THEN
			SET v_retTxt = 'Este precodigo no ha sido premiado';
			SET v_retNum = 1;
        ELSE
			IF cEstado != '0' THEN
				-- SET v_retTxt = CONCAT('Este precodigo no se encuentra disponible Fronta-Precodigo-Estado(', v_idFrontal, ' - ', v_precodigo, ' - ', cEstado,')');
                SET v_retTxt = CONCAT('Este precodigo no se encuentra disponible');
				SET v_retNum = 1;
			ELSE
				IF v_idCanje != 0 THEN
					SET v_retTxt = CONCAT('Este precodigo ya se encuentra canjeado (',v_idCanje,')');
					SET v_retNum = 2;
				ELSE
					IF dCaducidad < v_fecha THEN
						SET v_retTxt = CONCAT('Este precodigo ya ha caducado (',dCaducidad,')');
						SET v_retNum = 1;
						/*
						IF v_idParticipante IS NULL THEN
							 CALL hxxi_crea_participante (v_idApp,	v_user,	v_retNum,	v_retTxt,	v_idParticipante
														 ,v_precodigo,	null,	v_precodigo,		v_precodigo,		null
														 ,null, 	null,	null,	null);
							IF v_retNum < 0 THEN
								SIGNAL ex_controladas;
							END IF;                        
                        END IF;
						*/
					ELSE
						SET cDonde = concat("Hay campaña? ", ifnull(v_url,'url'), ' - ', v_idCampaign, ' - ', v_modulo, ' - ', ifnull(v_url, 'Url nula'));
						SELECT count(*) INTO nExiste 
						  FROM cdx_campaigns a
						 where a.id = v_idCampaign
						   and upper(ifnull(ruta_directo, ifnull(v_url,'url'))) COLLATE utf8mb4_general_ci = upper(ifnull(v_url,'url'))
						   and a.modulo COLLATE utf8mb4_general_ci = v_modulo
						   and now() between fecha_inicio and ifnull(fecha_fin, now());           
						IF nExiste != 1 THEN
							set v_retTxt = concat('El catálogo no existe (',nExiste,'):', v_url, ' - ', v_idApp, ' - ', v_modulo, ' - ', v_idCampaign);
							SIGNAL ex_controladas;
						ELSE
							SET cDonde = "Validando campaña";
							SELECT a.id_catalogo, a.max_canjes INTO v_idCatalogo, nMaxCanjes 
							  FROM cdx_campaigns a
							 where a.id = v_idCampaign
                               and upper(ifnull(ruta_directo, ifnull(v_url,'url'))) COLLATE utf8mb4_general_ci = upper(ifnull(v_url,'url'))
							   and a.modulo COLLATE utf8mb4_general_ci = v_modulo
							   and now() between fecha_inicio and ifnull(fecha_fin, now());           
						END IF;

						set cDonde = 'Comprobaciones nº canjes';
						Select count(*) into nExiste from cnj_canjes 
						 where id_app = v_idApp 
						   and modulo COLLATE utf8mb4_general_ci = v_modulo
						   and ifnull(id_campaign,-1) = ifnull(v_idCampaign, -1) -- La campaña solo existe de momento de CDX
						   and id_cat = v_idCatalogo; -- La campaña en canjes se puede repetir por ser de otro módulo que no sea CDX
						IF nExiste > ifnull(nMaxCanjes, nExiste) THEN
							set v_retTxt = concat('Pasado el límite (', nMaxCanjes, ') de canjes para esta campaña');
							SIGNAL ex_controladas;
						END IF;                    
					END IF;
				END IF;
			END IF;
        END IF;
    END IF;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cdx_valida_url`( IN v_idApp 		BIGINT  
																, IN v_user 		VARCHAR(45)         -- Usuario que lanza el procedimiento
																, INOUT v_retNum 	INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																, INOUT v_retTxt 	VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																, IN  v_url			VARCHAR(400)   -- 
                                                                , IN  v_modulo		VARCHAR(5)
																, IN  v_fecha 		VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																, OUT v_Frontal		BIGINT
																, OUT v_Catalogo	BIGINT
																)
BEGIN
/*
set @url = "hangarxxi2.com";
SELECT * FROM db_madre_dev.cdx_frontales where dominio = @url;

SELECT a.*
          FROM cdx_campaigns a
          inner join cdx_frontales b on b.id = a.id_frontal
		 where upper(ruta_directo) = upper(@url)
           and b.id_app = 58
           and modulo = v_modulo
           and now() between fecha_inicio and ifnull(fecha_fin, now());
*/
DECLARE nExiste		int;
DECLARE dFecha		datetime;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cdx_valida_url';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	SET v_Frontal = Null;
	SET v_Catalogo = Null;
    
	IF v_url is null Then
        set v_retTxt = 'No ha llegado URL';
		SIGNAL ex_controladas;
	END IF;

    -- comprobamos formato de la fecha
    Select g_fecha_ok(v_fecha , '%Y-%m-%d %H:%i:%s', 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
    END IF;
    
    SELECT id INTO v_Frontal FROM cdx_frontales where id_app = v_idApp and upper(dominio) COLLATE utf8mb4_general_ci = upper(v_url) and modulo COLLATE utf8mb4_general_ci = v_modulo;
    IF v_Frontal is NOT null Then
		SET v_retTxt = 'OK';
        SET v_retNum = 0;
	ELSE
		SELECT a.id_frontal, a.id_catalogo INTO v_Frontal, v_Catalogo 
          FROM cdx_campaigns a
          inner join cdx_frontales b on b.id = a.id_frontal
		 where upper(ruta_directo) COLLATE utf8mb4_general_ci = upper(v_url)
           and b.id_app = v_idApp
           and a.modulo COLLATE utf8mb4_general_ci = v_modulo
           and now() between fecha_inicio and ifnull(fecha_fin, now());
		IF v_Frontal is NOT null Then
			SET v_retTxt = 'OK';
			SET v_retNum = 0;
        ELSE
			set v_retTxt = 'El catálogo no existe';
			SIGNAL ex_controladas;
		END IF;   
    END IF;   
   
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cnj_crea`( IN v_idApp 			BIGINT  
														, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
														, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                     
														, IN  v_idParticipante 	bigint
														, IN  v_idCat 			bigint
														, IN  v_idProducto 		bigint
														, IN  v_links_vouchers  varchar(4000)     -- dato para poder acceder a la descarga del link de génesis. Formato: [{\"link\":\"https:\\/\\/gentestcore.helloyalty.cloud\\/download-voucher\\/2d8da74857d183ea59a5\",\"inicio_validez_cupon\":\"2022-05-12T18:34:16+02:00\",\"fin_validez_cupon\":null,\"valor\":\"10.00\"}]

														, IN  v_unidades 		int
														, IN  v_puntos 			decimal(8,2)	-- En positivo, puntos del canje
														, IN  v_fecCanje 		VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'

														, IN  v_nombre 			varchar(50)
														, IN  v_email 			varchar(255)
														, IN  v_telf 			varchar(15)
														, IN  v_fiscalNombre 	varchar(50)
														, IN  v_fiscalApellidos varchar(50)
														, IN  v_fiscalDni 		varchar(20)
														, IN  v_fiscalTelefono 	varchar(20)
														, IN  v_fiscalDirDir 	varchar(255)
														, IN  v_Dir			 	varchar(255)
														, IN  v_cp 				varchar(25)
														, IN  v_idProvincia 	bigint
														, IN  v_localidad 		varchar(255)

														, INOUT  v_estado 		varchar(1)
														, OUT  v_idCnj 			bigint
														, OUT  v_idMovCanje 	bigint
														, OUT v_saldo 			DECIMAL(11,2)   -- 
                                                        )
BEGIN
DECLARE nExiste			int;
DECLARE dFecha			datetime;
DECLARE nSaldo 			DECIMAL(11,2);
DECLARE cDescripcion	VARCHAR(250);
DECLARE nIdDir			BIGINT;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cnj_crea';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
    SET cDescripcion = 'Canje de producto';
    
	IF v_unidades is null Then
        set v_retTxt = 'Debe indicar una cantidad de unidades validas para el canje';
		SIGNAL ex_controladas;
	END IF;
	IF v_puntos is null THEN 
        set v_retTxt = 'Debe indicar unos puntos del canje';
		SIGNAL ex_controladas;
	END IF;


    -- comprobamos formato de la fecha
    Select g_fecha_ok(v_fecCanje , '%Y-%m-%d %H:%i:%s', 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
    END IF;
   
	IF IFNULL(v_idCat, 0) = 0 THEN 
        set v_retTxt = 'Debe indicar un id de catálogo';
		SIGNAL ex_controladas;
	else
        SELECT count(id)  INTO nExiste   FROM cat_definicion  WHERE id = v_idCat   AND id_app = v_idApp;
        IF nExiste = 0 Then
			set v_retTxt = 'El catálogo no existe';
			SIGNAL ex_controladas;
        END IF;
	END IF;    

	IF IFNULL(v_idProducto, 0) = 0 THEN 
        set v_retTxt = 'Debe indicar un id de Producto';
		SIGNAL ex_controladas;
	ELSE
        SELECT count(id)  INTO nExiste  FROM cat_cat_productos  WHERE id = v_idProducto and id_cat = v_idCat;  --  Aunque el catálogo no hace falta, ya que el id de producto es único
        IF nExiste = 0 Then
			set v_retTxt = concat('El Producto ', v_idProducto, ' no existe en el catálogo ', v_idCat);
			SIGNAL ex_controladas;
        END IF;
	END IF;
    
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
	SET cDonde = 'Creando movimiento cnj';
	CALL mov_crea_canje( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, null, NOW(), cDescripcion, -(v_puntos*v_unidades), 'Sin Fichero', v_idMovCanje, v_saldo);
	IF v_retNum != 0 THEN
		SIGNAL ex_controladas;
    END IF;
	
	-- SET cDonde = 'Creando dirección'; -- PDTE. Habría que comprobar los datos controladamente
    IF v_dir is not null then
		SET cDonde = concat('Insertando dirección: ', ifnull(v_dir, 'nula'));
		INSERT INTO dir_direcciones(tipo, id_participante,  id_provincia,  localidad,   cp,   direccion1, direccion2, numero, complemento, portal_bloque, escalera, planta, puerta, modified_by)
							Values(3,    v_idParticipante, v_idProvincia, v_localidad, v_cp, v_dir,  null,       null,   null,        null,          null,     null,   null,    v_user);
		IF v_retNum != 0 THEN
			SIGNAL ex_controladas;
		END IF;
		SELECT @@identity AS id into nIdDir;  
	End If;
  
	SET cDonde = concat('Insertando canje: ', ifnull(v_idParticipante, 'nulo'));
	INSERT INTO cnj_canjes  ( id_app, 		id_participante,  id_cat,            id_producto,   					unidades,            puntos,     fec_canje
							, fec_aprobado, fec_rechazado,    fec_anulado,       fec_enviado,   id_mov_canje,       id_mov_anula,        nombre,     email
							, telf,         fiscal_nombre,    fiscal_apellidos,  fiscal_dni,    fiscal_telefono,    fiscal_id_direccion, estado,     modified_by
                            ,links_vouchers)
					VALUES  ( v_idApp, 		v_idParticipante, v_idCat,           v_idProducto,  					v_unidades,          v_puntos,   v_fecCanje
							, fec_aprobado, NULL,             NULL,              fec_enviado,   v_idMovCanje,       NULL,                v_nombre,   v_email
							, v_telf,       v_fiscalNombre,   v_fiscalApellidos, v_fiscalDni,   v_fiscalTelefono,   nIdDir, 			 v_estado,   v_user
                            ,v_links_vouchers);
	SELECT @@identity AS id into v_idCnj;  
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cnj_crea_campos`( IN    v_idApp 		BIGINT  
																 , IN    v_user 		VARCHAR(45)    -- Usuario que lanza el procedimiento
																 , INOUT v_retNum 		INT            -- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
																 , INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                                 
																 , IN  v_idCanje		BIGINT			
																 , IN  v_modulo			VARCHAR(4)  
																 , IN  v_idModulo		BIGINT			-- en CDX será el id_campiagn
																 , IN  v_json_datos		VARCHAR(4000)  -- Ejemplo --> {"edad":{"valor": "21", "tipo":"C"}, "telefono":{"valor": "666596225", "tipo":"C"}}
                                                                 , IN  v_TipoProd		CHAR(1)
																 )
BEGIN
DECLARE cCampo		VARCHAR(100);
DECLARE cValor		VARCHAR(4000);
DECLARE cTipo 		CHAR(1);
DECLARE nIdCampo	INT;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql	VARCHAR(4000);
DECLARE errorNum	VARCHAR(4000);
DECLARE errorText	VARCHAR(4000);
DECLARE cDonde		VARCHAR(4000) default 'Inicio cnj_crea_campos';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de CURSORES
-- -----------------------------------------------------------------------------------------------------
DECLARE bFinCursor INT DEFAULT FALSE;

DECLARE cur1 CURSOR FOR 
	SELECT JSON_VALUE(JSON_KEYS(v_json_datos), CONCAT('$[', seq, ']')) 								 					as campo 
		  ,JSON_VALUE(v_json_datos, concat('$.', JSON_VALUE(JSON_KEYS(v_json_datos), CONCAT('$[', seq, ']')),'.valor'))	as valor
		  ,JSON_VALUE(v_json_datos, concat('$.', JSON_VALUE(JSON_KEYS(v_json_datos), CONCAT('$[', seq, ']')),'.tipo')) 	as tipo
	  FROM seq_0_to_100000000 WHERE seq < JSON_LENGTH(JSON_KEYS(v_json_datos));                            

DECLARE CONTINUE HANDLER FOR NOT FOUND SET bFinCursor = TRUE;

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		Call hxxi_crea_log(v_idApp , 'A', '1', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
		SET v_retNum = 2;
        set cDonde = 'Mal';
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET v_retNum = 0;
    SET cDonde = 'Apertura cursos';
	SET v_retTxt = 'Apertura curor';
    
    OPEN cur1;
	bucle:LOOP 
		SET bFinCursor = false
		  , cDonde 	   = 'leemos cursor';
		SET v_retTxt = 'Lectura del curor';
		FETCH cur1  into cCampo, cValor, cTipo;
        IF bFinCursor THEN
			LEAVE bucle;
        END IF;
                
		-- De momento solo es valida para CDX, porque hay que encontrar el IdCampo
        -- 16/03/2024 añadimos XPR
		IF v_modulo in  ('CDX', 'XPR') THEN
			CALL cdx_valida_campos_adic(v_idApp , v_user , v_retNum , v_retTxt , v_idModulo , cCampo, cTipo, v_TipoProd, nIdCampo);
			IF v_retNum < 0 THEN 
				SIGNAL ex_controladas;
			END IF;
		END IF;

		-- Si me llega un campo que no pasa la validación es que no existe definido para 
        -- esta campaña, por lo que se habrá metido en el json para otra cosa
		IF IFNULL(nIdCampo, 0) != 0 THEN
			SET v_retTxt = 'insert';
			SET cDonde = 'Creamos registro';
			INSERT INTO cnj_campos(id_canje,  modulo,   id_campo, valor)
							VALUES(v_idCanje, v_modulo, nIdCampo, cValor);
		END IF;

	END LOOP;
    CLOSE cur1;    
    
	SET v_retNum = 0;
	SET v_retTxt = 'Ok';
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cnj_crea_completo`( IN v_idApp 			BIGINT  
														, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
														, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                     
														, IN  v_idParticipante 	bigint
														, IN  v_idCat 			bigint
														, IN  v_idProdSem 		bigint			  -- Puede ser un canje normal o de Semillas. en el caso de ser de semillas no es un producto si no una semilla, con sus respectivas validaciones,...
														, IN  v_idCampaign 		bigint
														, IN  v_links_vouchers  varchar(4000)     -- dato para poder acceder a la descarga del link de génesis. Formato: [{\"link\":\"https:\\/\\/gentestcore.helloyalty.cloud\\/download-voucher\\/2d8da74857d183ea59a5\",\"inicio_validez_cupon\":\"2022-05-12T18:34:16+02:00\",\"fin_validez_cupon\":null,\"valor\":\"10.00\"}]

														, IN  v_unidades 		int
														, IN  v_puntos 			decimal(8,2)	-- En positivo, puntos del canje
														, IN  v_fecCanje 		VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'

														, IN  v_fecAprobado 	VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
														, IN  v_fecEnviado	 	VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
                                                        
														, IN  v_modulo			VARCHAR(4)     	-- Como CAT o CDX, XPR....
														, IN  v_json_datos		VARCHAR(4000)   -- Datos de campos variablesvariable
														, IN  v_json_fichero	VARCHAR(4000)   -- Lista de ficheros asociados al canje
                                                            
														, IN  v_nombre 			varchar(50)
														, IN  v_email 			varchar(255)
														, IN  v_telf 			varchar(15)
                                                        , INOUT v_idDir			BIGINT       -- si viene este campo no se tiene en cuenta la dirección
														, IN  v_dir1	 		varchar(255)
														, IN  v_numero	 		varchar(10)
														, IN  v_dir2	 		varchar(255)
														, IN  v_CP				varchar(25)
														, IN  v_idProv			bigint
														, IN  v_localidad 		varchar(255)
														, IN  v_pais	 		varchar(10)

														, IN  v_fiscalNombre 	varchar(50)
														, IN  v_fiscalApellidos varchar(50)
														, IN  v_fiscalDni 		varchar(20)
														, IN  v_fiscalTelefono 	varchar(20)
                                                        , INOUT v_idFiscalDir	BIGINT       -- si viene este campo no se tiene en cuenta la dirección
														, IN  v_fiscalDir1	 	varchar(255)
														, IN  v_fiscalCP		varchar(25)
														, IN  v_fiscalIdProv	bigint
														, IN  v_fiscalLocalidad varchar(255)

														, INOUT  v_estado 		varchar(1)
														, OUT v_idCnj 			bigint
														, OUT v_idMovCanje 		bigint
														, OUT v_saldo 			DECIMAL(11,2)   -- 
                                                        , OUT v_Tipos			VARCHAR(500)
                                                        )
BEGIN
DECLARE nExiste			int;
DECLARE dFecha			datetime;
DECLARE dEnviado		DATETIME default null;
DECLARE dAprobado		DATETIME default null;
DECLARE cFormato		VARCHAR(19) default '%Y-%m-%d %H:%i:%s';
DECLARE nSaldo 			DECIMAL(11,2);
DECLARE cDescripcion	VARCHAR(250);
DECLARE cTipoProd		CHAR(1);
			
-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cnj_crea_completo';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
            
		SET v_retNum = -2;
		Call hxxi_crea_log(v_idApp , 'A', '1', v_user, errorNum, errorText, errorMySql, concat(cDonde, '. MiError4'),  v_retNum, v_retTxt); 
	End;    

-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
    SET cDescripcion = 'Canje de producto';
    
	IF v_unidades is null Then
        set v_retTxt = 'Debe indicar una cantidad de unidades validas para el canje';
		SIGNAL ex_controladas;
	END IF;
	IF v_puntos is null THEN 
        set v_retTxt = 'Debe indicar unos puntos del canje';
		SIGNAL ex_controladas;
	END IF;

    -- comprobamos formato de la fecha del canje
    Select g_fecha_ok(v_fecCanje , cFormato, 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
	ELSE
		select STR_TO_DATE(v_fecCanje, cFormato) into dFecha;
    END IF;
   
    -- comprobamos formato de la fecha de la aprobación
    Select g_fecha_ok(v_fecAprobado , cFormato, 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
	ELSE
		select STR_TO_DATE(v_fecAprobado, cFormato) into dAprobado;
    END IF;
   
    -- comprobamos formato de la fecha de envio
    Select g_fecha_ok(v_fecEnviado , cFormato, 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
	ELSE
		select STR_TO_DATE(v_fecEnviado, cFormato) into dEnviado;
    END IF;
    
    IF dEnviado IS NOT null and dAprobado IS null THEN
		SET dAprobado = dEnviado;
    END IF;
    
	IF IFNULL(v_idProdSem, 0) = 0 THEN 
		set v_retTxt = 'Debe indicar un id de Producto/Semilla';
		SIGNAL ex_controladas;
	END IF;

	IF v_modulo = 'XPR' THEN -- si son experiencias se debe grabar semilla, no producto
		SELECT count(a.id) 
		  INTO nExiste  
		  FROM exp_experiencias  a
		 WHERE a.id = v_idProdSem and now() BETWEEN a.desde AND ifnull(a.hasta, now()+1);
		 
		IF nExiste = 0 Then
			set v_retTxt = concat('La semilla ', v_idProdSem, ' no existe para la fecha actual: ', now());
			SIGNAL ex_controladas;
		END IF;
        
        set cTipoProd = 'D'; -- de momento los productos de semillas solo son digitales
        
        -- Validar que la experiencia es de una categoria del catalogo recibido.
	ELSE
		IF IFNULL(v_idCat, 0) = 0 THEN 
			set v_retTxt = 'Debe indicar un id de catálogo';
			SIGNAL ex_controladas;
		ELSE
			SELECT count(id)  INTO nExiste   FROM cat_definicion  WHERE id = v_idCat   AND id_app = v_idApp;
			IF nExiste = 0 Then
				set v_retTxt = 'El catálogo no existe';
				SIGNAL ex_controladas;
			END IF;
		END IF;    
        
		-- SELECT count(id)  INTO nExiste  FROM cat_cat_productos  WHERE id = v_idProdSem and id_cat = v_idCat;  --  Aunque el catálogo no hace falta, ya que el id de producto es único
		SELECT if(b.tipo_prod = "0", 'D', if(b.tipo_prod = "1", 'F', 'O') ) tipo, count(*) 
		  INTO cTipoProd, nExiste  
		  FROM cat_cat_productos  a
		 INNER JOIN cat_productos as b ON a.id_producto = b.id
		 WHERE a.id = v_idProdSem and a.id_cat = v_idCat
		 GROUP BY tipo;
		 
		IF nExiste = 0 Then
			set v_retTxt = concat('El Producto ', v_idProdSem, ' no existe en el catálogo ', v_idCat);
			SIGNAL ex_controladas;
		END IF;
    END IF;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
	SET cDonde = 'Creando movimiento cnj';
	CALL mov_crea_canje( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, null, NOW(), cDescripcion, -(v_puntos*v_unidades), 'Sin Fichero', v_idMovCanje, v_saldo);
	IF v_retNum != 0 THEN
		SIGNAL ex_controladas;
    END IF;

	-- SET cDonde = 'Creando dirección'; -- PDTE. Habría que comprobar los datos controladamente
    IF v_dir1 is not null and IFNULL(v_idDir, 0) = 0 then
		SET cDonde = concat('Insertando dirección: ', ifnull(v_dir1, 'nula'));
		CALL dir_crea	( v_idApp 	, v_user, v_retNum	, v_retTxt	, v_idParticipante	, "2"			
						, v_dir1	, v_dir2, v_numero	, null		, null				, null  , null		, null		
						, v_CP		, v_pais, null		, v_idProv	, v_localidad		, v_idDir);
		IF v_retNum != 0 THEN
			SIGNAL ex_controladas;
		END IF;
	END IF;



    IF (v_fiscalDir1 is not null AND length(v_fiscalDir1) > 2) AND IFNULL(v_idFiscalDir, 0) = 0 then
		SET cDonde = concat('Insertando dirección Fiscal: ', ifnull(v_fiscalDir1, 'nula'));
		CALL dir_crea	( v_idApp 		, v_user, v_retNum	, v_retTxt		, v_idParticipante	, "3"			
						, v_fiscalDir1	, null	, null		, null			, null				, null  , null		, null		
						, v_fiscalCP	, null	, null		, v_fiscalIdProv, v_fiscalLocalidad	, v_idFiscalDir);
		IF v_retNum != 0 THEN
			SIGNAL ex_controladas;
		END IF;
	END IF;
  
	SET cDonde = concat('Insertando canje: ', ifnull(v_idParticipante, 'nulo'), ' - ',v_email, ' - ',ifnull(v_idProdSem, 'nulo'));
	INSERT INTO cnj_canjes  ( id_app,				id_participante, 	id_cat
							, id_producto
							, id_semilla
                            , id_campaign,			modulo,			 	fec_canje, 			fec_aprobado,  fec_enviado
                            , id_mov_canje,			links_vouchers,	 	unidades,			puntos
                            , nombre,           	email,			 	telf,       		id_direccion
                            , fiscal_id_direccion,	fiscal_nombre,	 	fiscal_apellidos,	fiscal_dni
                            , fiscal_telefono,		estado,			 	modified_by)
					VALUES  ( v_idApp, 		 		v_idParticipante,	v_idCat
							, if(v_modulo = 'XPR', NULL, 		v_idProdSem)
                            , if(v_modulo = 'XPR', v_idProdSem,	NULL)
							, v_idCampaign, 		v_modulo,		 	dFecha, 		 	dAprobado, 		dEnviado
                            , v_idMovCanje, 		v_links_vouchers,	v_unidades,			v_puntos
                            , v_nombre,         	v_email,		 	v_telf,				v_idDir
                            , v_idFiscalDir, 		v_fiscalNombre,	 	v_fiscalApellidos,	v_fiscalDni
                            , v_fiscalTelefono,		v_estado,		 	v_user);
	SELECT @@identity AS id into v_idCnj;  

	-- -----------------------------------------------------------------------------------------------------
    -- Añadimos los campos
	-- -----------------------------------------------------------------------------------------------------
	set cDonde = 'Creando campos canje';
	CALL cnj_crea_campos (v_idApp, v_user, v_retNum, v_retTxt, v_idCnj, v_modulo, v_idCampaign, v_json_datos, cTipoProd);
	IF v_retNum < 0 THEN
		SIGNAL ex_controladas;
	END IF;                            

	-- -----------------------------------------------------------------------------------------------------
    -- Añadimos los ficheros
	-- -----------------------------------------------------------------------------------------------------
    if v_json_fichero is not null THEN
		set cDonde = 'Creando campos ficheros';
		CALL cnj_crea_ficheros (v_idApp, v_user, v_retNum, v_retTxt, v_idCnj, v_modulo, v_json_fichero, v_Tipos);
        
		IF v_retNum != 0 THEN
			SIGNAL ex_controladas;
		END IF;                            
    END IF;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cnj_crea_comprueba`( IN v_idApp 			BIGINT  
														, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
														, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                     
														, IN  v_idParticipante 	bigint
														, IN  v_idCat 			bigint
														, IN  v_idProducto 		bigint
														, IN  v_links_vouchers  varchar(4000)     -- dato para poder acceder a la descarga del link de génesis. Formato: [{\"link\":\"https:\\/\\/gentestcore.helloyalty.cloud\\/download-voucher\\/2d8da74857d183ea59a5\",\"inicio_validez_cupon\":\"2022-05-12T18:34:16+02:00\",\"fin_validez_cupon\":null,\"valor\":\"10.00\"}]

														, IN  v_unidades 		int
														, IN  v_puntos 			decimal(8,2)	-- En positivo, puntos del canje
														, IN  v_fecCanje 		VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'

														, IN  v_nombre 			varchar(50)
														, IN  v_email 			varchar(255)
														, IN  v_telf 			varchar(15)
														, IN  v_fiscalNombre 	varchar(50)
														, IN  v_fiscalApellidos varchar(50)
														, IN  v_fiscalDni 		varchar(20)
														, IN  v_fiscalTelefono 	varchar(20)
														, IN  v_fiscalDirDir 	varchar(255)
														, IN  v_Dir			 	varchar(255)
														, IN  v_cp 				varchar(25)
														, IN  v_idProvincia 	bigint
														, IN  v_localidad 		varchar(255)

														, INOUT  v_estado 		varchar(1)
                                                        )
BEGIN
DECLARE nExiste			int;
DECLARE dFecha			datetime;
DECLARE nidConcepto		BIGINT;   
DECLARE cCncpt			CHAR(1);
DECLARE cFecCaducidad	Varchar(19);
DECLARE dCaducidad		DATE;
DECLARE nSaldo 			DECIMAL(11,2);

DECLARE cSegundos		Varchar(15);
DECLARE nSegundos		INT;
DECLARE xLabel			Varchar(500);
DECLARE xTooltip		Varchar(500);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cnj_crea_comprueba';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	SET v_retNum = 0;
    SET v_retTxt = 'Validacion Ok.';
    
  	IF v_user is null THEN 
        set v_retTxt = 'Debe indicar un Usuario respponsable creador del movimiento';
		SIGNAL ex_controladas;
	END IF;

	IF IFNULL(v_puntos, 0) < 0  THEN 
        set v_retTxt = 'Los puntos deben ser positivos en la comprobación';
		SIGNAL ex_controladas;
	END IF;
    
	IF v_unidades is null Then
        set v_retTxt = 'Debe indicar una cantidad de unidades validas para el canje';
		SIGNAL ex_controladas;
	END IF;

	set dFecha = str_to_date(v_fecCanje, '%Y-%m-%d %H:%i:%s');
	IF v_fecCanje is null THEN 
        set v_retTxt = 'Debe indicar una fecha';
		SIGNAL ex_controladas;
	END IF;



    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada propias del CANJE
    -- -----------------------------------------------------------------------------------------------------
    -- comprobamos formato de la fecha
    Select g_fecha_ok(v_fecCanje , '%Y-%m-%d %H:%i:%s', 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
    END IF;
   
	IF IFNULL(v_idCat, 0) = 0 THEN 
        set v_retTxt = 'Debe indicar un id de catálogo';
		SIGNAL ex_controladas;
	else
        SELECT count(id)  INTO nExiste   FROM cat_definicion  WHERE id = v_idCat   AND id_app = v_idApp;
        IF nExiste = 0 Then
			set v_retTxt = 'El catálogo no existe';
			SIGNAL ex_controladas;
        END IF;
	END IF;    

	IF IFNULL(v_idProducto, 0) = 0 THEN 
        set v_retTxt = 'Debe indicar un id de Producto';
		SIGNAL ex_controladas;
	ELSE
        SELECT count(id)  INTO nExiste  FROM cat_cat_productos  WHERE id = v_idProducto and id_cat = v_idCat;  --  Aunque el catálogo no hace falta, ya que el id de producto es único
        IF nExiste = 0 Then
			set v_retTxt = 'El Producto no existe en catálogos';
			SIGNAL ex_controladas;
        END IF;
	END IF;

	IF IFNULL(v_idParticipante, 0) = 0 THEN 
        set v_retTxt = 'Debe indicar un id de participante';
		SIGNAL ex_controladas;
	else
        SELECT count(id)  INTO nExiste   FROM hxxi_participantes  WHERE id = v_idParticipante   AND id_app = v_idApp;
        IF nExiste = 0 Then
			set v_retTxt = 'El participante no existe';
			SIGNAL ex_controladas;
        END IF;
	END IF;
    
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada propias del MOVIMIENTO de CANJE
    -- -----------------------------------------------------------------------------------------------------
	-- ---------------------  Control de concepto  --------------------------------------------------------------------------
    SET cDonde 	= 'Búsqueda de concepto canje';
    Call g_mov_busca_cncpt( v_idApp , v_user , v_retNum , v_retTxt , 'movimientos' , 'canje' , 'U', nidConcepto);
    IF v_retNum != 0 THEN
		SIGNAL ex_controladas; 
	END IF;
  
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada propias del MOVIMIENTO
    -- ----------------------------------------------------------------------------------------------------- 
    -- Validar que tiene saldo sufienciente en caso de resta
    SET cDonde = 'Buscando saldo';
    Select saldo - v_puntos into nSaldo from hxxi_participantes_totales  WHERE id_participante = v_IdParticipante;
    select row_count() into nExiste;
    IF nExiste = 0 THEN
		SET nSaldo = -1 * v_puntos;
    END IF;
    IF nSaldo < 0 THEN
		set v_retTxt = CONCAT('Esta operación (de ', v_puntos,' puntos) no se puede realizar porque se queda el saldo inferior a cero (', nSaldo, ').');
		SIGNAL ex_controladas;
    END IF;
   
    -- -----------------------------------------------------------------------------------------------------
    -- No se pueden hacer dos canjes seguidos en menos de los X segundos planificados
    -- ----------------------------------------------------------------------------------------------------- 
	CALL hxxi_configuracion( v_idApp , v_user , v_retNum , v_retTxt , NULL , "canjes", "segundos" , cSegundos , xLabel , xTooltip); 
	IF v_retNum != 0  THEN 
		SIGNAL ex_controladas;
	END IF;
	Select CAST(cSegundos AS UNSIGNED) into nSegundos;

	SELECT count(*) into nExiste FROM cnj_canjes a 
     WHERE id_participante = v_IdParticipante 
       AND created_at > TIMESTAMPADD(SECOND,nSegundos*-1,now()) 
     ORDER BY id DESC LIMIT 1;
     
    SET cDonde = CONCAT("Segundos de intervalo: ", cSegundos, "Canjes en menos tiempo: ", IFNULL(nExiste, 0));
    IF IFNULL(nExiste, 0) != 0 THEN
		set v_retTxt = "No se pueden realizar operaciones de canje tan seguidas. Por favor, vuelva  intentarlo.";
		SIGNAL ex_controladas;
    END IF;   
   
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cnj_crea_ficheros`( IN    v_idApp 	BIGINT  
																	, IN    v_user 		VARCHAR(45)    -- Usuario que lanza el procedimiento
																	, INOUT v_retNum 	INT            -- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
																	, INOUT v_retTxt 	VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                                 
																	, IN  v_idCanje		BIGINT			
																	, IN  v_modulo		VARCHAR(4)  
																	, IN  v_json_datos	VARCHAR(4000)  -- Ejemplo --> {"edad":{"valor": "21", "tipo":"C"}, "telefono":{"valor": "666596225", "tipo":"C"}}
                                                                    , INOUT v_tipo  	VARCHAR(100)   -- Cadena con los tipos de fichero que existen
																	)
BEGIN
DECLARE cLocalizacion 	VARCHAR(500);
DECLARE cFichero		VARCHAR(100);
DECLARE cExtension		VARCHAR(5);
DECLARE cTipo 			VARCHAR(10);
DECLARE nIdCampo		INT;


-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cnj_crea_ficheros';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de CURSORES
-- -----------------------------------------------------------------------------------------------------
DECLARE bFinCursor INT DEFAULT FALSE;

DECLARE cur1 CURSOR FOR 
	SELECT JSON_VALUE(JSON_KEYS(v_json_datos), CONCAT('$[', seq, ']')) 								 							as tipo 
		  ,JSON_VALUE(v_json_datos, concat('$.', JSON_VALUE(JSON_KEYS(v_json_datos), CONCAT('$[', seq, ']')),'.localizacion'))	as localizacion
		  ,JSON_VALUE(v_json_datos, concat('$.', JSON_VALUE(JSON_KEYS(v_json_datos), CONCAT('$[', seq, ']')),'.fichero'))		as fichero
		  ,JSON_VALUE(v_json_datos, concat('$.', JSON_VALUE(JSON_KEYS(v_json_datos), CONCAT('$[', seq, ']')),'.extension')) 	as extension
	  FROM seq_0_to_100000000 WHERE seq < JSON_LENGTH(JSON_KEYS(v_json_datos));                            

DECLARE CONTINUE HANDLER FOR NOT FOUND SET bFinCursor = TRUE;

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'Apertura cursor';
	SET v_retTxt = 'Apertura cursor';
    SET v_tipo = " ";
	SET v_retNum = 0;
    
    OPEN cur1;
	bucle:LOOP 
		SET bFinCursor = false
		  , cDonde 	   = 'leemos cursor';
		SET v_retTxt = 'Lectura cursor';
		FETCH cur1  into cTipo, cLocalizacion , cFichero, cExtension;
        IF bFinCursor THEN
			LEAVE bucle;
        END IF;

		IF v_modulo = 'CDX' THEN
			IF cLocalizacion is null OR cFichero IS NULL OR cTipo IS NULL THEN 
				SET v_retTxt = 'Error de parámetros';
				SIGNAL ex_controladas;
			END IF;
            SET v_tipo = TRIM(concat(v_tipo, ',', cTipo));
		END IF;

        SET nIdCampo = 0;
		SET v_retTxt = 'insert';
		SET cDonde = 'Creamos registro';
        
		INSERT INTO cnj_ficheros (id_canje,  modulo, localizacion, fichero, extension, tipo)
						  VALUES (v_idCanje, v_modulo, cLocalizacion, cFichero, cExtension, cTipo);	
	END LOOP;
    CLOSE cur1;    
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`cnt_borra`( IN    v_idApp BIGINT          -- (Valor nulo --> 0)   
													, IN v_user VARCHAR(45)         -- Usuario que lanza el procedimiento
													, INOUT v_retNum INT            -- 0 --> OK campña borrada; <0 --> error;
													, INOUT v_retTxt VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
													, IN v_id_contenido BIGINT
													)
BEGIN
DECLARE nExiste       INTEGER;

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cnt_borra';
-- DECLARE ex_validaciones CONDITION FOR SQLSTATE '45001';
DECLARE ex_controladas	CONDITION FOR SQLSTATE '45000';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
            
		Rollback;
            
		SET FOREIGN_KEY_CHECKS = 1; -- Por si da error mientras estaba desactivado
        SET v_retTxt =  concat(cDonde, '\n', errorText, '\n', errorMySql);
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

DECLARE exit HANDLER FOR ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
            
		Rollback;
            
		SET FOREIGN_KEY_CHECKS = 1; -- Por si da error mientras estaba desactivado
        SET v_retTxt =  concat(cDonde, '\n', errorText, '\n', errorMySql);
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
/*
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;
*/
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	SELECT count(id) into nExiste FROM cnt_contenidos where id = v_id_contenido;
	IF nExiste != 1 THEN
		set cDonde = CONCAT('El contenido: ', v_id_contenido, ' no existe');
		-- SIGNAL ex_controladas;
	ELSE
		-- -----------------------------------------------------------------------------------------------------
		-- PROCESO
		-- -----------------------------------------------------------------------------------------------------
		-- ----------------------------------------------------------------------------------------------------
		-- Peligro, estamos desactivando las FK
		-- Lo hago porquee s circular, primero habría que poner a null uno de los dos y eso es un update mas....
		-- ----------------------------------------------------------------------------------------------------
		SET FOREIGN_KEY_CHECKS = 0; -- en realidad solo para cnt_contenidos con points_clientes
		SET sql_safe_updates = 0;
		
			SET cDonde = 'Borramos cnt_valores: ';
			delete from cnt_valores 
			 where id_posiciona in (select id from cnt_posiciona b where b.id_cnt_contenidos = v_id_contenido);
			SET cDonde = concat(cDonde, ROW_COUNT(), '\n');
			
			SET cDonde = concat(cDonde, 'Borramos cnt_posiciona: ');
			delete from cnt_posiciona where id_cnt_contenidos = v_id_contenido;
			SET cDonde = concat(cDonde, ROW_COUNT(), '\n');

			SET cDonde = concat(cDonde, 'Borramos cnt_contenidos: ');
			delete from cnt_contenidos where id = v_id_contenido;
			SET cDonde = concat(cDonde, ROW_COUNT(), '\n');
		
		SET sql_safe_updates = 1;
		SET FOREIGN_KEY_CHECKS = 1;
		-- ----------------------------------------------------------------------------------------------------
		-- FIN Peligro
		-- ----------------------------------------------------------------------------------------------------
		SET cDonde = concat(cDonde, 'No se borran los ficheros físicos contenidos de la parametrización de clientes');
	END IF;
	
    SET v_retNum  = 0;
    SET v_retTxt =  cDonde;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`dir_crea`( IN v_idApp 			BIGINT  
														  , IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
														  , INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														  , INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum !=0)
                                                     
														  , IN  v_idParticipante bigint
														  , IN  v_tipo			char(1)			-- 1 --> personal; 2 --> canje; 3 --> Fiscal (no se puede modificar)
														  , IN  v_dir1	 		varchar(255)
														  , IN  v_dir2			varchar(255)
														  , IN  v_numero		varchar(15)
														  , IN  v_complemento	varchar(15)
														  , IN  v_portal_bloque	varchar(15)
														  , IN  v_escalera		varchar(15)
														  , IN  v_planta		varchar(15)
														  , IN  v_puerta		varchar(15)
														  , IN  v_CP			varchar(25)
                                                          , IN  v_codPais		varchar(25)
                                                          , IN  v_codComunidad	varchar(25)
														  , IN  v_codProv		varchar(25)
														  , IN  v_localidad 	varchar(255)

														  , OUT  v_idDir 			bigint
                                                          )
BEGIN
DECLARE nExiste			int;
DECLARE nPais 			bigint;
DECLARE nComunidad 		bigint;
DECLARE cComunidad 		varchar(25);
DECLARE nProv 			bigint;
DECLARE cCP				varchar(15) default v_CP;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio dir_crea';
DECLARE ex_controladas  CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -------------------------------------------------------------------------------------------------
	CALL dir_valida( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, v_tipo, v_dir1, v_dir2, v_CP, v_codPais, v_codComunidad, v_codProv, v_localidad, nPais, nComunidad, nProv);
	IF v_retNum != 0 THEN
		SIGNAL ex_controladas;
    END IF;
    	
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
		SET cDonde = concat('Insertando dirección: ', v_dir1);
		INSERT INTO dir_direcciones(tipo,  id_participante,  id_provincia,  localidad,   cp,  direccion1, direccion2, numero,   complemento,   portal_bloque,   escalera,   planta,   puerta,   modified_by)
							Values(v_tipo, v_idParticipante, nProv,         v_localidad, cCP, v_dir1,     v_dir2,     v_numero, v_complemento, v_portal_bloque, v_escalera, v_planta, v_puerta, v_user);

		SELECT @@identity AS id into v_idDir;  
		SET v_retNum= 0;  
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`dir_modifica`( IN v_idApp 			BIGINT  
														  , IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
														  , INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														  , INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum !=0)
                                                     
														  , IN  v_id			bigint
														  , IN  v_idParticipante bigint
														  , IN  v_tipo			char(1)			-- 1 --> personal; 2 --> canje; 3 --> Fiscal (no se puede modificar)
														  , IN  v_dir1	 		varchar(255)
														  , IN  v_dir2			varchar(255)
														  , IN  v_numero		varchar(15)
														  , IN  v_complemento	varchar(15)
														  , IN  v_portal_bloque	varchar(15)
														  , IN  v_escalera		varchar(15)
														  , IN  v_planta		varchar(15)
														  , IN  v_puerta		varchar(15)
														  , IN  v_CP			varchar(25)
                                                          , IN  v_codPais		varchar(25)
                                                          , IN  v_codComunidad	varchar(25)
														  , IN  v_codProv		varchar(25)
														  , IN  v_localidad 	varchar(255)
                                                          )
BEGIN
DECLARE nExiste			int;
DECLARE nPais 			bigint;
DECLARE nComunidad 		bigint;
DECLARE cComunidad 		varchar(25);
DECLARE nProv 			bigint;
DECLARE cCP				varchar(15) default v_CP;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio dir_modifica';
DECLARE ex_controladas  CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -------------------------------------------------------------------------------------------------
	CALL dir_valida( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, v_tipo, v_dir1, v_dir2, v_CP, v_codPais, v_codComunidad, v_codProv, v_localidad, nPais, nComunidad, nProv);
	IF v_retNum != 0 THEN
		SIGNAL ex_controladas;
    END IF;
    
	SET cDonde = concat('Comprobando dirección: ', v_dir1);
	SELECT count(*) into nExiste from dir_direcciones Where	id = v_id;
	IF nExiste != 1 THEN
		set v_retTxt = concat('La dirección ', v_dir1, ' (', v_id, ') no existe');
		SIGNAL ex_controladas;
	END IF;
            
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
		SET cDonde = concat('Modificando dirección: ', v_dir1);
        UPDATE	dir_direcciones
		   SET	tipo			= v_tipo
			   ,id_participante	= v_idParticipante
               ,id_provincia	= nProv
               ,localidad		= v_localidad
               ,cp				= v_CP
               ,direccion1		= v_dir1
               ,direccion2		= v_dir2
               ,numero			= v_numero
               ,complemento		= v_complemento
               ,portal_bloque	= v_portal_bloque
               ,escalera		= v_escalera
               ,planta			= v_planta
               ,puerta			= v_puerta
               ,modified_by		= v_user
		Where	id = v_id;

		SET v_retNum= 0;  
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`dir_valida`( IN v_idApp 			BIGINT  
														  , IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
														  , INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														  , INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum !=0)
                                                     
														  , IN  v_idParticipante bigint
														  , IN  v_tipo			char(1)			-- 1 --> personal; 2 --> canje; 3 --> Fiscal (no se puede modificar)
														  , IN  v_dir1	 		varchar(255)
														  , IN  v_dir2			varchar(255)
														  , INOUT  v_CP			varchar(25)
                                                          , IN  v_codPais		varchar(25)
                                                          , IN  v_codComunidad	varchar(25)
														  , IN  v_codProv		varchar(25)
														  , IN  v_localidad 	varchar(255)
                                                          , OUT v_idPais		int
                                                          , OUT v_idComunidad 	int
                                                          , OUT v_idProv		int
                                                          )
BEGIN
DECLARE nExiste			int;
DECLARE cComunidad 		varchar(25);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio dir_valida';
DECLARE ex_controladas  CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -------------------------------------------------------------------------------------------------
    set cDonde = 'Comprobando dir1';
    IF v_dir1 is null then
        set v_retTxt = 'Debe indicar una Direccion';
		SIGNAL ex_controladas;
	End If;

    set cDonde = 'Comprobando CP';
    IF v_CP is null and v_localidad is null then
        set v_retTxt = 'Debe indicar un CP o una localidad';
		SIGNAL ex_controladas;
	End If;
    
    set cDonde = 'Comprobando tipo';
    IF IFNULL(v_tipo, '0') NOT IN ('1','2','3') then
        set v_retTxt = 'El tipo de dirección no es correcto';
		SIGNAL ex_controladas;
	End If;
    
	set cDonde = 'Comprobando Provincia';
	IF v_codProv is NULL THEN 
        set v_retTxt = 'Debe indicar un id de provincia';
		SIGNAL ex_controladas;
	END IF;
    
	SELECT id            	INTO v_idPais   	 		 FROM dir_paises  	 WHERE codigo COLLATE utf8mb4_general_ci = IFNULL(v_codPais, "ES");
	SELECT id, id_comunidad	INTO v_idProv, v_idComunidad FROM dir_provincias WHERE codigo COLLATE utf8mb4_general_ci = v_codProv AND id_pais = v_idPais;
	IF v_idProv IS NULL OR v_idComunidad IS NULL THEN
		set v_retTxt = concat('La provincia "', v_codProv, '" no se corresponde o no existe para el pais "', IFNULL(v_codPais, "ES"), '"');
		SIGNAL ex_controladas;
	END IF;
    
	set cDonde = 'Comprobando Comunidad';
	IF v_codComunidad is not null then
		SELECT codigo            INTO cComunidad	 FROM dir_comunidades  WHERE id = v_idComunidad;
		set cDonde = 'Comprobando Comunidades';
		IF cComunidad != v_codComunidad then
			set v_retTxt = concat('La provincia ', v_codProv, ' no se corresponde o no existe para el pais ', IFNULL(v_codPais, "ES"), ' y comunidad ', v_codComunidad);
			SIGNAL ex_controladas;
		END IF;
	END IF;
    IF IFNULL(v_codPais, "ES") = "ES" THEN
		IF v_CP is not null then
			IF LENGTH(v_CP) > 5 THEN
				set v_retTxt = 'Código postal erróneo';
				SIGNAL ex_controladas;
            ELSE
				IF LENGTH(v_CP) < 5 THEN
					SET v_CP = lpad(v_CP, 5, '0');
				END IF;
                IF v_codProv != left(v_CP, 2) THEN
					set v_retTxt = 'Código postal no corresponde con la provincia';
					SIGNAL ex_controladas;
                END IF;
            END IF;
		End If;
    END IF;
	
	SET v_retNum = 0;  
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`exp_canje`( IN v_idApp			 BIGINT  
															, IN v_user 			 VARCHAR(45)         -- Usuario que lanza el procedimiento
															, INOUT v_retNum 		 INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt 		 VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                                
															, IN  v_precodigo		 VARCHAR(25) 
															, INOUT v_idParticipante BIGINT 
															, IN  v_id_frontal		 BIGINT 
															, IN  v_id_campaign		 BIGINT 
															, IN  v_id_semilla		 BIGINT 
															, IN  v_id_cat			 BIGINT 
															, IN  v_id_centro		 BIGINT 
                                                            
															, IN  v_unidades	 	 INT 
															, IN  v_puntos		 	 INT 
															, IN  v_fec_canje		 VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
															, IN  v_links_vouchers	 VARCHAR(4000)
                                                            
                                                            , IN  v_json_datos		 VARCHAR(4000)     -- Datos de campos variables
															, IN  v_json_fichero	 VARCHAR(4000)     -- Lista de ficheros asociados al canje

															, OUT v_id   			 BIGINT          -- ID de la operación creada
															)
BEGIN
DECLARE nExiste			 INT;
DECLARE dFechaCanje		 DATETIME;
DECLARE dEnviado		 DATETIME default null;

DECLARE nFrontal		 BIGINT default v_id_frontal;
DECLARE nCampaign		 BIGINT;
DECLARE nParticipante	 BIGINT;
DECLARE nCatalogo	 	 BIGINT;
DECLARE xURL			 VARCHAR(200);

DECLARE dInicioCampa	 DATETIME;
DECLARE dFinCampa		 DATETIME;
DECLARE cPremiodir		 VARCHAR(1);
DECLARE nStatus		 	 INT;
DECLARE nMaxCanjes		 INT;
DECLARE cTipos			 VARCHAR(500);
DECLARE cTieneTicket	 CHAR(1);
DECLARE nLimiteFiscal	 INT default 400;
DECLARE xLabel		 	 VARCHAR(500);
DECLARE xTooltip		 VARCHAR(500);

DECLARE cNombre			 VARCHAR(200);
DECLARE cEmail			 VARCHAR(200);
DECLARE cTelf			 VARCHAR(15);
DECLARE ndDir			 BIGINT;

DECLARE cDir1		 	 VARCHAR(200);
DECLARE cNumero		 	 VARCHAR(10);
DECLARE cDir2		 	 VARCHAR(200);
DECLARE nIdProv		 	 BIGINT;
DECLARE cCP			 	 VARCHAR(10);
DECLARE cLocalidad 	 	 VARCHAR(75);
DECLARE cPais	 	 	 VARCHAR(2);

DECLARE cEstado			 VARCHAR(1);
DECLARE nIdMovCanje		 BIGINT;	
DECLARE nSaldo			 INT;
DECLARE cComentario		 VARCHAR(4000);

DECLARE xFiscal_nombre	 VARCHAR(200);
DECLARE xFiscal_apell	 VARCHAR(200);
DECLARE xFiscal_dni		 VARCHAR(19);
DECLARE xFiscal_telf	 VARCHAR(19);
DECLARE xIdFiscalDir	 BIGINT;
DECLARE xFiscal_dir1	 VARCHAR(200);
DECLARE xFiscal_id_prov	 BIGINT;
DECLARE xFiscal_CP		 VARCHAR(10);
DECLARE xFiscal_localidad VARCHAR(75);

DECLARE nIdPrecodigo	 BIGINT;
DECLARE cPremiado		 CHAR(1);
DECLARE cEstadoPreCod 	 CHAR(1);
DECLARE fCaducidad		 DATETIME;
DECLARE xCanje		 	 DATETIME;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cdx_canje';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;

		SET v_retNum = null;
		SET v_retTxt = null;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = -2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	SET cDonde = 'Comprobaciones0';
   	SET v_retNum = 0;

	IF v_precodigo is null Then
		SELECT g_texto('No_ha_llegado_Precódigo.', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones01';
	IF ifnull(v_id_frontal,0) = 0 Then
        SELECT g_texto('No_ha_llegado_id_frontal', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones02';
	IF ifnull(v_id_campaign,0) = 0 Then
        SELECT g_texto('No_ha_llegado_id_campaign', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones03';
	IF IFNULL(v_unidades, 0) <= 0 is null Then
        SELECT g_texto('No_han_llegado_unidades', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones04';
	IF IFNULL(v_puntos,0) <= 0 is null Then
        SELECT g_texto('No_han_llegado_puntos.', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

    -- comprobamos formato de la fecha
    Select g_fecha_ok(v_fec_canje , '%Y-%m-%d %H:%i:%s', 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
	ELSE 
		select STR_TO_DATE(v_fec_canje, '%Y-%m-%d %H:%i:%s') into dFechaCanje;
    END IF;
    
	-- -----------------------------------------------------------------------------------------------------
    -- Desgranamos los campos de los variables que son obligatorios
	-- -----------------------------------------------------------------------------------------------------
	set cDonde = 'Comprobaciones80'; Select g_cdx_extrae_campo("nombre", v_json_datos) into cNombre;
	set cDonde = 'Comprobaciones81'; Select g_cdx_extrae_campo("email", v_json_datos) into cEmail;
	set cDonde = 'Comprobaciones82'; Select g_cdx_extrae_campo("telefono", v_json_datos) into cTelf;
	set cDonde = 'Comprobaciones83'; Select g_cdx_extrae_campo("idDir", v_json_datos) into ndDir;
	IF ndDir is NULL THEN
		set cDonde = 'Comprobaciones84'; Select g_cdx_extrae_campo("calle", v_json_datos) into cDir1;
		set cDonde = 'Comprobaciones85'; Select g_cdx_extrae_campo("numero", v_json_datos) into cNumero;
		set cDonde = 'Comprobaciones86'; Select g_cdx_extrae_campo("dir_adicionales", v_json_datos) into cDir2;
		set cDonde = 'Comprobaciones87'; Select g_cdx_extrae_campo("cp", v_json_datos) into cCP;
		set cDonde = 'Comprobaciones88'; Select g_cdx_extrae_campo("localidad", v_json_datos) into cLocalidad;
		set cDonde = 'Comprobaciones89'; Select g_cdx_extrae_campo("provincia", v_json_datos) into nIdProv;
		set cDonde = 'Comprobaciones90'; Select g_cdx_extrae_campo("pais", v_json_datos) into cPais;
	ELSE		
		SELECT	direccion1,	numero, 	direccion2,	cp,		id_provincia,	'ES'
		  INTO	cDir1, 		cNumero,	cDir2,		cCP,	nIdProv,		cPais
		  FROM  dir_direcciones
         WHERE  id = ndDir;
	END IF;
    
	set cDonde = 'Comprobaciones91'; 
	IF ifnull(v_idParticipante,0) = 0 Then
        CALL hxxi_crea_participante (v_idApp,	v_user,	v_retNum,	v_retTxt,	v_idParticipante
									,cNombre,	null,	cEmail,		cEmail,		cTelf
                                    ,concat(cDir1, ' ', cNumero, ' ', cDir2), 	cCP,	nIdProv,	cPais);
		IF v_retNum < 0 THEN
			SIGNAL ex_controladas;
        END IF;
	ELSE
		Select count(id) into nExiste from hxxi_participantes where id = v_idParticipante;
		IF nExiste = 0 Then
   			SELECT g_texto('El_participante_no_Existe', v_idApp) INTO v_retTxt;
			SIGNAL ex_controladas;
		END IF;
    END IF;

	-- -----------------------------------------------------------------------------------------------------
	set cDonde = concat('Validando Precodigo ', v_precodigo); 
	CALL cdx_valida_precodigo(v_idApp, v_user, v_retNum, v_retTxt, 'XPR', v_precodigo, dFechaCanje, xURL, nFrontal ,nCatalogo, nCampaign, xCanje, nParticipante, nIdPrecodigo);
	IF v_retNum != 0  THEN 
		SIGNAL ex_controladas;
	END IF;
	IF v_id_frontal != nFrontal THEN
        SELECT g_texto('Error_Campaña/Frontal', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;
	-- -----------------------------------------------------------------------------------------------------
	-- -----------------------------------------------------------------------------------------------------
    -- 1--> Realizado: El participante ha hecho el pedido y hay que enviarlo, no tiene confirmación.
    -- 2--> Pendiente confirmar: El cliente ha hecho el pedido, pero es un pedido pendiente de confirmación.
    -- 3--> Confirmado: El cliente ha hecho un pedido que necesita confirmación y un gestor lo ha confirmado.
    -- 4--> Rechazado: El cliente ha hecho el pedido que necesita confirmación y un gestor lo ha anulado (aunque podría ser un proceso el que lo ha rechazado).
    -- 5-->Anulado: Un pedido ya creado se ha anulado (por el motivo que sea).
    -- 6--> Enviado: en pedidos realizados o confirmados. El pedido se ha enviado. En los digitales es cuando se envía el email o sms, en los físicos es cuando se descarga el fichero para el proveedor logístico.
	-- -----------------------------------------------------------------------------------------------------
    IF cTieneTicket = 'S' OR cPremiodir = 'S' THEN
		SET cEstado			= "2"; -- Pendiente confirmar: El cliente ha hecho el pedido, pero es un pedido pendiente de confirmación.
       	SET v_retNum 		= 2;
    ELSE
        IF true THEN
			SET cEstado		= "1"; -- Realizado: El participante ha hecho el pedido y hay que enviarlo, no tiene confirmación.
            SET dEnviado	= dFechaCanje;	 
			SET v_retNum 	= 1;
        ELSE
			SET cEstado		= "6"; -- Enviado: en pedidos realizados o confirmados. El pedido se ha enviado. En los digitales es cuando se envía el email o sms, en los físicos es cuando se descarga el fichero para el proveedor logístico.
			SET v_retNum 	= 6;
        END IF;
    END IF;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
	-- -----------------------------------------------------------------------------------------------------
    SET v_retTxt = 'OK';
    SET v_retNum = 0;
   
	-- -----------------------------------------------------------------------------------------------------
    -- Creamos el movimiento de canje, que ya de por sí hacae VALIDACIONES
	-- -----------------------------------------------------------------------------------------------------
	set cDonde = 'Creando canje completo';
	Call cnj_crea_Completo	( v_idApp			, v_user        , v_retNum     		, v_retTxt		
							, v_idParticipante	, v_id_cat  	, v_id_semilla		, v_id_campaign	 , v_links_vouchers 
                            , v_unidades		, v_puntos      , v_fec_canje  		, null			 , dEnviado
                            , "XPR"				, v_json_datos  , v_json_fichero	, cNombre	  	 , cEmail		, cTelf       
                            , ndDir				, cDir1	 	 	, cNumero			, cDir2			 , cCP		  	, nIdProv		, cLocalidad , cPais
                            , xFiscal_nombre	, xFiscal_apell , xFiscal_dni 		, xFiscal_telf 	
                            , xIdFiscalDir		, xFiscal_dir1  , xFiscal_CP  		, xFiscal_id_prov, xFiscal_localidad 
                            , cEstado			, v_id			, nIdMovCanje  		, nSaldo		 , cTipos);

	IF v_retNum != 0  THEN 
		SIGNAL ex_controladas;
	END IF;
	-- -------------------------------------------------------------------------------------------------------
    -- Actualizamos el PRECODIGO
	-- -------------------------------------------------------------------------------------------------------
	set cDonde = 'Actualizando precodigo';
	UPDATE cdx_precodigos
       SET id_participante	= v_idParticipante
		  ,id_canje			= v_id
          ,status			= "1" -- '0 --> sin enviar (ya sea a un fichero o por emal/sms); 1 --> Activo (se ha enviado); 2 --> Inactivo (se ha anulado, pero siempre antes de canjear)',    
          ,modified_by		= v_user
	 WHERE id = nIdPrecodigo;
    
	set cDonde = 'Fin Funcion';
	SELECT g_texto('Canje_realizado_con_éxito.', v_idApp) INTO v_retTxt;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`exp_canje2`( IN v_idApp			 	 BIGINT  
															, IN v_user 			 VARCHAR(45)         -- Usuario que lanza el procedimiento
															, INOUT v_retNum 		 INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt 		 VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                                
															, IN  v_precodigo		 VARCHAR(25) 
															, INOUT v_idParticipante BIGINT 
															, IN  v_id_frontal		 BIGINT 
															, IN  v_id_campaign		 BIGINT 
															, IN  v_id_exp			 BIGINT 
															, IN  v_id_semilla		 BIGINT 
															, IN  v_id_cat			 BIGINT 
                                                            
															, IN  v_unidades	 	 INT 
															, IN  v_puntos		 	 INT 
															, IN  v_fec_canje		 VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
															, IN  v_links_vouchers	 VARCHAR(4000)
                                                            
                                                            , IN  v_json_datos		 VARCHAR(4000)     -- Datos de campos variables
															, IN  v_json_fichero	 VARCHAR(4000)     -- Lista de ficheros asociados al canje

															, OUT v_id   		BIGINT          -- ID de la operación creada
															)
BEGIN
DECLARE nExiste			 INT;
DECLARE dFechaCanje		 DATETIME;
DECLARE dEnviado		 DATETIME default null;

DECLARE nFrontal		 BIGINT default v_id_frontal;
DECLARE nCampaign		 BIGINT;
DECLARE nParticipante	 BIGINT;
DECLARE nCatalogo	 	 BIGINT;
DECLARE xURL			 VARCHAR(200);

DECLARE dInicioCampa	 DATETIME;
DECLARE dFinCampa		 DATETIME;
DECLARE cPremiodir		 VARCHAR(1);
DECLARE nStatus		 	 INT;
DECLARE nMaxCanjes		 INT;
DECLARE cTipos			 VARCHAR(500);
DECLARE cTieneTicket	 CHAR(1);
DECLARE nLimiteFiscal	 INT default 400;
DECLARE xLabel		 	 VARCHAR(500);
DECLARE xTooltip		 VARCHAR(500);

DECLARE cNombre			 VARCHAR(200);
DECLARE cEmail			 VARCHAR(200);
DECLARE cTelf			 VARCHAR(15);
DECLARE ndDir			 BIGINT;

DECLARE cDir1		 	 VARCHAR(200);
DECLARE cNumero		 	 VARCHAR(10);
DECLARE cDir2		 	 VARCHAR(200);
DECLARE nIdProv		 	 BIGINT;
DECLARE cCP			 	 VARCHAR(10);
DECLARE cLocalidad 	 	 VARCHAR(75);
DECLARE cPais	 	 	 VARCHAR(2);

DECLARE cEstado			 VARCHAR(1);
DECLARE nIdMovCanje		 BIGINT;	
DECLARE nSaldo			 INT;
DECLARE cComentario		 VARCHAR(4000);

DECLARE xFiscal_nombre	 VARCHAR(200);
DECLARE xFiscal_apell	 VARCHAR(200);
DECLARE xFiscal_dni		 VARCHAR(19);
DECLARE xFiscal_telf	 VARCHAR(19);
DECLARE xIdFiscalDir	 BIGINT;
DECLARE xFiscal_dir1	 VARCHAR(200);
DECLARE xFiscal_id_prov	 BIGINT;
DECLARE xFiscal_CP		 VARCHAR(10);
DECLARE xFiscal_localidad VARCHAR(75);

DECLARE nIdPrecodigo	 BIGINT;
DECLARE cPremiado		 CHAR(1);
DECLARE cEstadoPreCod 	 CHAR(1);
DECLARE fCaducidad		 DATETIME;
DECLARE xCanje		 	 DATETIME;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cdx_canje';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;

		SET v_retNum = null;
		SET v_retTxt = null;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = -2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	SET cDonde = 'Comprobaciones0';
   	SET v_retNum = 0;

	IF v_precodigo is null Then
		SELECT g_texto('No_ha_llegado_Precódigo.', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones01';
	IF ifnull(v_id_frontal,0) = 0 Then
        SELECT g_texto('No_ha_llegado_id_frontal', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones02';
	IF ifnull(v_id_campaign,0) = 0 Then
        SELECT g_texto('No_ha_llegado_id_campaign', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones03';
	IF IFNULL(v_unidades, 0) <= 0 is null Then
        SELECT g_texto('No_han_llegado_unidades', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones04';
	IF IFNULL(v_puntos,0) <= 0 is null Then
        SELECT g_texto('No_han_llegado_puntos.', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

    -- comprobamos formato de la fecha
    Select g_fecha_ok(v_fec_canje , '%Y-%m-%d %H:%i:%s', 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
	ELSE 
		select STR_TO_DATE(v_fec_canje, '%Y-%m-%d %H:%i:%s') into dFechaCanje;
    END IF;
    
	-- -----------------------------------------------------------------------------------------------------
    -- Desgranamos los campos de los variables que son obligatorios
	-- -----------------------------------------------------------------------------------------------------
	set cDonde = 'Comprobaciones80'; Select g_cdx_extrae_campo("nombre", v_json_datos) into cNombre;
	set cDonde = 'Comprobaciones81'; Select g_cdx_extrae_campo("email", v_json_datos) into cEmail;
	set cDonde = 'Comprobaciones82'; Select g_cdx_extrae_campo("telefono", v_json_datos) into cTelf;
	set cDonde = 'Comprobaciones83'; Select g_cdx_extrae_campo("idDir", v_json_datos) into ndDir;
	IF ndDir is NULL THEN
		set cDonde = 'Comprobaciones84'; Select g_cdx_extrae_campo("calle", v_json_datos) into cDir1;
		set cDonde = 'Comprobaciones85'; Select g_cdx_extrae_campo("numero", v_json_datos) into cNumero;
		set cDonde = 'Comprobaciones86'; Select g_cdx_extrae_campo("dir_adicionales", v_json_datos) into cDir2;
		set cDonde = 'Comprobaciones87'; Select g_cdx_extrae_campo("cp", v_json_datos) into cCP;
		set cDonde = 'Comprobaciones88'; Select g_cdx_extrae_campo("localidad", v_json_datos) into cLocalidad;
		set cDonde = 'Comprobaciones89'; Select g_cdx_extrae_campo("provincia", v_json_datos) into nIdProv;
		set cDonde = 'Comprobaciones90'; Select g_cdx_extrae_campo("pais", v_json_datos) into cPais;
	ELSE		
		SELECT	direccion1,	numero, 	direccion2,	cp,		id_provincia,	'ES'
		  INTO	cDir1, 		cNumero,	cDir2,		cCP,	nIdProv,		cPais
		  FROM  dir_direcciones
         WHERE  id = ndDir;
	END IF;
    
	set cDonde = 'Comprobaciones91'; 
	IF ifnull(v_idParticipante,0) = 0 Then
        CALL hxxi_crea_participante (v_idApp,	v_user,	v_retNum,	v_retTxt,	v_idParticipante
									,cNombre,	null,	cEmail,		cEmail,		cTelf
                                    ,concat(cDir1, ' ', cNumero, ' ', cDir2), 	cCP,	nIdProv,	cPais);
		IF v_retNum < 0 THEN
			SIGNAL ex_controladas;
        END IF;
	ELSE
		Select count(id) into nExiste from hxxi_participantes where id = v_idParticipante;
		IF nExiste = 0 Then
   			SELECT g_texto('El_participante_no_Existe', v_idApp) INTO v_retTxt;
			SIGNAL ex_controladas;
		END IF;
    END IF;

	-- -----------------------------------------------------------------------------------------------------
	set cDonde = concat('Validando Precodigo ', v_precodigo); 
	CALL cdx_valida_precodigo(v_idApp, v_user, v_retNum, v_retTxt, 'XPR', v_precodigo, dFechaCanje, xURL, nFrontal ,nCatalogo, nCampaign, xCanje, nParticipante, nIdPrecodigo);
	IF v_retNum != 0  THEN 
		SIGNAL ex_controladas;
	END IF;
	IF v_id_frontal != nFrontal THEN
        SELECT g_texto('Error_Campaña/Frontal', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;
	-- -----------------------------------------------------------------------------------------------------
	-- -----------------------------------------------------------------------------------------------------
    -- 1--> Realizado: El participante ha hecho el pedido y hay que enviarlo, no tiene confirmación.
    -- 2--> Pendiente confirmar: El cliente ha hecho el pedido, pero es un pedido pendiente de confirmación.
    -- 3--> Confirmado: El cliente ha hecho un pedido que necesita confirmación y un gestor lo ha confirmado.
    -- 4--> Rechazado: El cliente ha hecho el pedido que necesita confirmación y un gestor lo ha anulado (aunque podría ser un proceso el que lo ha rechazado).
    -- 5-->Anulado: Un pedido ya creado se ha anulado (por el motivo que sea).
    -- 6--> Enviado: en pedidos realizados o confirmados. El pedido se ha enviado. En los digitales es cuando se envía el email o sms, en los físicos es cuando se descarga el fichero para el proveedor logístico.
	-- -----------------------------------------------------------------------------------------------------
    IF cTieneTicket = 'S' OR cPremiodir = 'S' THEN
		SET cEstado			= "2"; -- Pendiente confirmar: El cliente ha hecho el pedido, pero es un pedido pendiente de confirmación.
       	SET v_retNum 		= 2;
    ELSE
        IF true THEN
			SET cEstado		= "1"; -- Realizado: El participante ha hecho el pedido y hay que enviarlo, no tiene confirmación.
            SET dEnviado	= dFechaCanje;	 
			SET v_retNum 	= 1;
        ELSE
			SET cEstado		= "6"; -- Enviado: en pedidos realizados o confirmados. El pedido se ha enviado. En los digitales es cuando se envía el email o sms, en los físicos es cuando se descarga el fichero para el proveedor logístico.
			SET v_retNum 	= 6;
        END IF;
    END IF;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
	-- -----------------------------------------------------------------------------------------------------
    SET v_retTxt = 'OK';
    SET v_retNum = 0;
   
	-- -----------------------------------------------------------------------------------------------------
    -- Creamos el movimiento de canje, que ya de por sí hacae VALIDACIONES
	-- -----------------------------------------------------------------------------------------------------
	set cDonde = 'Creando canje completo';
	Call cnj_crea_Completo	( v_idApp			, v_user        , v_retNum     		, v_retTxt		
							, v_idParticipante	, v_id_cat  	, v_id_semilla		, v_id_campaign	 , v_links_vouchers 
                            , v_unidades		, v_puntos      , v_fec_canje  		, null			 , dEnviado
                            , "XPR"				, v_json_datos  , v_json_fichero	, cNombre	  	 , cEmail		, cTelf       
                            , ndDir				, cDir1	 	 	, cNumero			, cDir2			 , cCP		  	, nIdProv		, cLocalidad , cPais
                            , xFiscal_nombre	, xFiscal_apell , xFiscal_dni 		, xFiscal_telf 	
                            , xIdFiscalDir		, xFiscal_dir1  , xFiscal_CP  		, xFiscal_id_prov, xFiscal_localidad 
                            , cEstado			, v_id			, nIdMovCanje  		, nSaldo		 , cTipos);

	IF v_retNum != 0  THEN 
		SIGNAL ex_controladas;
	END IF;
	-- -------------------------------------------------------------------------------------------------------
    -- Actualizamos el PRECODIGO
	-- -------------------------------------------------------------------------------------------------------
	set cDonde = 'Actualizando precodigo';
	UPDATE cdx_precodigos
       SET id_participante	= v_idParticipante
		  ,id_canje			= v_id
          ,status			= "1" -- '0 --> sin enviar (ya sea a un fichero o por emal/sms); 1 --> Activo (se ha enviado); 2 --> Inactivo (se ha anulado, pero siempre antes de canjear)',    
          ,modified_by		= v_user
	 WHERE id = nIdPrecodigo;
    
	set cDonde = 'Fin Funcion';
	SELECT g_texto('Canje_realizado_con_éxito.', v_idApp) INTO v_retTxt;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`exp_canje__antigua`( IN v_idApp			 	 BIGINT  
															, IN v_user 			 VARCHAR(45)         -- Usuario que lanza el procedimiento
															, INOUT v_retNum 		 INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt 		 VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                                
															, IN  v_precodigo		 VARCHAR(25) 
															, INOUT v_idParticipante BIGINT 
															, IN  v_id_frontal		 BIGINT 
															, IN  v_id_campaign		 BIGINT 
															, IN  v_id_exp			 BIGINT 
															, IN  v_id_prod			 BIGINT 
															, IN  v_id_cat			 BIGINT 
                                                            
															, IN  v_unidades	 	 INT 
															, IN  v_puntos		 	 INT 
															, IN  v_fec_canje		 VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
															, IN  v_links_vouchers	 VARCHAR(4000)
                                                            
                                                            , IN  v_json_datos		 VARCHAR(4000)     -- Datos de campos variables
															, IN  v_json_fichero	 VARCHAR(4000)     -- Lista de ficheros asociados al canje

															, OUT v_id   		BIGINT          -- ID de la operación creada
															)
BEGIN
DECLARE nExiste			 INT;
DECLARE dFechaCanje		 DATETIME;
DECLARE dEnviado		 DATETIME default null;

DECLARE nFrontal		 BIGINT default v_id_frontal;
DECLARE nCampaign		 BIGINT;
DECLARE nParticipante	 BIGINT;
DECLARE nCatalogo	 	 BIGINT;
DECLARE xURL			 VARCHAR(200);

DECLARE dInicioCampa	 DATETIME;
DECLARE dFinCampa		 DATETIME;
DECLARE cPremiodir		 VARCHAR(1);
DECLARE nStatus		 	 INT;
DECLARE nMaxCanjes		 INT;
DECLARE cTipos			 VARCHAR(500);
DECLARE cTieneTicket	 CHAR(1);
DECLARE nLimiteFiscal	 INT default 400;
DECLARE xLabel		 	 VARCHAR(500);
DECLARE xTooltip		 VARCHAR(500);

DECLARE cNombre			 VARCHAR(200);
DECLARE cEmail			 VARCHAR(200);
DECLARE cTelf			 VARCHAR(15);
DECLARE ndDir			 BIGINT;

DECLARE cDir1		 	 VARCHAR(200);
DECLARE cNumero		 	 VARCHAR(10);
DECLARE cDir2		 	 VARCHAR(200);
DECLARE nIdProv		 	 BIGINT;
DECLARE cCP			 	 VARCHAR(10);
DECLARE cLocalidad 	 	 VARCHAR(75);
DECLARE cPais	 	 	 VARCHAR(2);

DECLARE cEstado			 VARCHAR(1);
DECLARE nIdMovCanje		 BIGINT;	
DECLARE nSaldo			 INT;
DECLARE cComentario		 VARCHAR(4000);

DECLARE xFiscal_nombre	 VARCHAR(200);
DECLARE xFiscal_apell	 VARCHAR(200);
DECLARE xFiscal_dni		 VARCHAR(19);
DECLARE xFiscal_telf	 VARCHAR(19);
DECLARE xIdFiscalDir	 BIGINT;
DECLARE xFiscal_dir1	 VARCHAR(200);
DECLARE xFiscal_id_prov	 BIGINT;
DECLARE xFiscal_CP		 VARCHAR(10);
DECLARE xFiscal_localidad VARCHAR(75);

DECLARE nIdPrecodigo	 BIGINT;
DECLARE cPremiado		 CHAR(1);
DECLARE cEstadoPreCod 	 CHAR(1);
DECLARE fCaducidad		 DATETIME;
DECLARE xCanje		 	 DATETIME;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio cdx_canje';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;

		SET v_retNum = null;
		SET v_retTxt = null;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = -2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	SET cDonde = 'Comprobaciones0';
   	SET v_retNum = 0;

	IF v_precodigo is null Then
		SELECT g_texto('No_ha_llegado_Precódigo.', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones01';
	IF ifnull(v_id_frontal,0) = 0 Then
        SELECT g_texto('No_ha_llegado_id_frontal', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones02';
	IF ifnull(v_id_campaign,0) = 0 Then
        SELECT g_texto('No_ha_llegado_id_campaign', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones03';
	IF IFNULL(v_unidades, 0) <= 0 is null Then
        SELECT g_texto('No_han_llegado_unidades', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = 'Comprobaciones04';
	IF IFNULL(v_puntos,0) <= 0 is null Then
        SELECT g_texto('No_han_llegado_puntos.', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;

    -- comprobamos formato de la fecha
    Select g_fecha_ok(v_fec_canje , '%Y-%m-%d %H:%i:%s', 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
	ELSE 
		select STR_TO_DATE(v_fec_canje, '%Y-%m-%d %H:%i:%s') into dFechaCanje;
    END IF;
    
	-- -----------------------------------------------------------------------------------------------------
    -- Desgranamos los campos de los variables que son obligatorios
	-- -----------------------------------------------------------------------------------------------------
	set cDonde = 'Comprobaciones80'; Select g_cdx_extrae_campo("nombre", v_json_datos) into cNombre;
	set cDonde = 'Comprobaciones81'; Select g_cdx_extrae_campo("email", v_json_datos) into cEmail;
	set cDonde = 'Comprobaciones82'; Select g_cdx_extrae_campo("telefono", v_json_datos) into cTelf;
	set cDonde = 'Comprobaciones83'; Select g_cdx_extrae_campo("idDir", v_json_datos) into ndDir;
	IF ndDir is NULL THEN
		set cDonde = 'Comprobaciones84'; Select g_cdx_extrae_campo("calle", v_json_datos) into cDir1;
		set cDonde = 'Comprobaciones85'; Select g_cdx_extrae_campo("numero", v_json_datos) into cNumero;
		set cDonde = 'Comprobaciones86'; Select g_cdx_extrae_campo("dir_adicionales", v_json_datos) into cDir2;
		set cDonde = 'Comprobaciones87'; Select g_cdx_extrae_campo("cp", v_json_datos) into cCP;
		set cDonde = 'Comprobaciones88'; Select g_cdx_extrae_campo("localidad", v_json_datos) into cLocalidad;
		set cDonde = 'Comprobaciones89'; Select g_cdx_extrae_campo("provincia", v_json_datos) into nIdProv;
		set cDonde = 'Comprobaciones90'; Select g_cdx_extrae_campo("pais", v_json_datos) into cPais;
	ELSE		
		SELECT	direccion1,	numero, 	direccion2,	cp,		id_provincia,	'ES'
		  INTO	cDir1, 		cNumero,	cDir2,		cCP,	nIdProv,		cPais
		  FROM  dir_direcciones
         WHERE  id = ndDir;
	END IF;
    
	set cDonde = 'Comprobaciones91'; 
	IF ifnull(v_idParticipante,0) = 0 Then
        CALL hxxi_crea_participante (v_idApp,	v_user,	v_retNum,	v_retTxt,	v_idParticipante
									,cNombre,	null,	cEmail,		cEmail,		cTelf
                                    ,concat(cDir1, ' ', cNumero, ' ', cDir2), 	cCP,	nIdProv,	cPais);
		IF v_retNum < 0 THEN
			SIGNAL ex_controladas;
        END IF;
	ELSE
		Select count(id) into nExiste from hxxi_participantes where id = v_idParticipante;
		IF nExiste = 0 Then
   			SELECT g_texto('El_participante_no_Existe', v_idApp) INTO v_retTxt;
			SIGNAL ex_controladas;
		END IF;
    END IF;

	-- -----------------------------------------------------------------------------------------------------
	set cDonde = concat('Validando Precodigo ', v_precodigo); 
	CALL cdx_valida_precodigo(v_idApp, v_user, v_retNum, v_retTxt, 'XPR', v_precodigo, dFechaCanje, xURL, nFrontal ,nCatalogo, nCampaign, xCanje, nParticipante, nIdPrecodigo);
	IF v_retNum != 0  THEN 
		SIGNAL ex_controladas;
	END IF;
	IF v_id_frontal != nFrontal THEN
        SELECT g_texto('Error_Campaña/Frontal', v_idApp) INTO v_retTxt;
		SIGNAL ex_controladas;
	END IF;
	-- -----------------------------------------------------------------------------------------------------
	-- -----------------------------------------------------------------------------------------------------
    -- 1--> Realizado: El participante ha hecho el pedido y hay que enviarlo, no tiene confirmación.
    -- 2--> Pendiente confirmar: El cliente ha hecho el pedido, pero es un pedido pendiente de confirmación.
    -- 3--> Confirmado: El cliente ha hecho un pedido que necesita confirmación y un gestor lo ha confirmado.
    -- 4--> Rechazado: El cliente ha hecho el pedido que necesita confirmación y un gestor lo ha anulado (aunque podría ser un proceso el que lo ha rechazado).
    -- 5-->Anulado: Un pedido ya creado se ha anulado (por el motivo que sea).
    -- 6--> Enviado: en pedidos realizados o confirmados. El pedido se ha enviado. En los digitales es cuando se envía el email o sms, en los físicos es cuando se descarga el fichero para el proveedor logístico.
	-- -----------------------------------------------------------------------------------------------------
    IF cTieneTicket = 'S' OR cPremiodir = 'S' THEN
		SET cEstado			= "2"; -- Pendiente confirmar: El cliente ha hecho el pedido, pero es un pedido pendiente de confirmación.
       	SET v_retNum 		= 2;
    ELSE
        IF true THEN
			SET cEstado		= "1"; -- Realizado: El participante ha hecho el pedido y hay que enviarlo, no tiene confirmación.
            SET dEnviado	= dFechaCanje;	 
			SET v_retNum 	= 1;
        ELSE
			SET cEstado		= "6"; -- Enviado: en pedidos realizados o confirmados. El pedido se ha enviado. En los digitales es cuando se envía el email o sms, en los físicos es cuando se descarga el fichero para el proveedor logístico.
			SET v_retNum 	= 6;
        END IF;
    END IF;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
	-- -----------------------------------------------------------------------------------------------------
    SET v_retTxt = 'OK';
    SET v_retNum = 0;
   
	-- -----------------------------------------------------------------------------------------------------
    -- Creamos el movimiento de canje, que ya de por sí hacae VALIDACIONES
	-- -----------------------------------------------------------------------------------------------------
	set cDonde = 'Creando canje completo';
	Call cnj_crea_Completo	( v_idApp			, v_user        , v_retNum     		, v_retTxt		
							, v_idParticipante	, v_id_cat  	, v_id_prod			, v_id_campaign	 , v_links_vouchers 
                            , v_unidades		, v_puntos      , v_fec_canje  		, null			 , dEnviado
                            , "XPR"				, v_json_datos  , v_json_fichero	, cNombre	  	 , cEmail		, cTelf       
                            , ndDir				, cDir1	 	 	, cNumero			, cDir2			 , cCP		  	, nIdProv		, cLocalidad , cPais
                            , xFiscal_nombre	, xFiscal_apell , xFiscal_dni 		, xFiscal_telf 	
                            , xIdFiscalDir		, xFiscal_dir1  , xFiscal_CP  		, xFiscal_id_prov, xFiscal_localidad 
                            , cEstado			, v_id			, nIdMovCanje  		, nSaldo		 , cTipos);

	IF v_retNum != 0  THEN 
		SIGNAL ex_controladas;
	END IF;
	-- -------------------------------------------------------------------------------------------------------
    -- Actualizamos el PRECODIGO
	-- -------------------------------------------------------------------------------------------------------
	set cDonde = 'Actualizando precodigo';
	UPDATE cdx_precodigos
       SET id_participante	= v_idParticipante
		  ,id_canje			= v_id
          ,status			= "1" -- '0 --> sin enviar (ya sea a un fichero o por emal/sms); 1 --> Activo (se ha enviado); 2 --> Inactivo (se ha anulado, pero siempre antes de canjear)',    
          ,modified_by		= v_user
	 WHERE id = nIdPrecodigo;
    
	set cDonde = 'Fin Funcion';
	SELECT g_texto('Canje_realizado_con_éxito.', v_idApp) INTO v_retTxt;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`exp_valida_precodigo`( IN v_idApp 				BIGINT  
																	  , IN v_user 				VARCHAR(45)         -- Usuario que lanza el procedimiento
																	  , INOUT v_retNum 			INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado. 2 --> El precodigo ya ha sido canjeado
																	  , INOUT v_retTxt 			VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																	  , IN  v_modulo			VARCHAR(5)
																	  , INOUT  v_precodigo		VARCHAR(30)
																	  , IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																	  , IN  v_url				VARCHAR(400) 	-- LLeva URL o ....
																	  , INOUT v_idFrontal		BIGINT			-- ... lleva IdFrontal
																	  , OUT v_idCatalogo		BIGINT
																	  , OUT v_idCampaign		BIGINT
                                                                      , OUT v_idCanje			BIGINT
																	  , OUT v_idParticipante	BIGINT
                                                                      , OUT v_idPrecodigo		BIGINT
																	  )
BEGIN
DECLARE nExiste			 int;
DECLARE dFecha			 datetime;

DECLARE cPremiado		 CHAR(1);
DECLARE cEstado			 CHAR(1);
DECLARE dCaducidad		 datetime;
DECLARE nMaxCanjes		 BIGINT;

DECLARE nIdCampaign		 BIGINT;
DECLARE cPecodigoReal	 VARCHAR(30);
DECLARE nIdPreCodigoReal BIGINT;
      
-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio exp_valida_precodigo';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;

		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = -2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	-- -----------------------------------------------------------------------------------------------------
    -- Vamos a lanzar un proceso para recuperar precodigos con 0 y sin canje de mas de una hora, que esto
    -- significa que alguien ha entrado, le hemos asignado un código pero no ha hecho el canje
    -- ---- mejorable ----
	-- -----------------------------------------------------------------------------------------------------
	SET cDonde = "Update masivo para pasar de 0 a 3 sin canje";
	UPDATE cdx_precodigos
       SET status = '3'   			-- Les ponemos como que son libres solo para campañas de tipo PRECODIGO UNICO
          ,modified_by = v_user
     WHERE status = '0' 			-- Si está libre
       AND id_canje is NULL			-- Y no tiene canje
       AND updated_at < DATE_ADD(now(), INTERVAL -2 HOUR)	-- y hace mas de una hora que fué actualizada
       AND id_campaign in (select id from cdx_campaigns where precodigo_unico is not null);-- Es de una campaña de precodigo único
	-- ----------
	-- ----------
	Commit;
	-- ----------
	-- ----------

	-- -----------------------------------------------------------------------------------------------------
    -- Validaciones
	-- -----------------------------------------------------------------------------------------------------
    -- Solo vamos a validar que sea PreCódigo UNICO o No, el resto ya se hace en cdx_valida_precodigo
	IF v_precodigo IS NULL THEN
        set v_retTxt = 'No ha llegado PRECODIGO';
		SIGNAL ex_controladas;
	END IF;

	SET cDonde = "Contando precodigo Único";
    SELECT count(*) INTO nExiste FROM cdx_campaigns where precodigo_unico COLLATE utf8mb4_general_ci = v_precodigo;
	IF nExiste = 1 THEN
		SET cDonde = "Buscando id Campaña";
        SELECT id INTO nIdCampaign FROM cdx_campaigns where precodigo_unico COLLATE utf8mb4_general_ci = v_precodigo;

		SET cDonde = "Contando y bloque precodigo Único";
		SELECT count(*) INTO nExiste
		  FROM cdx_precodigos where id_campaign = nIdCampaign and status = '3';
		IF nExiste >= 1 Then
			SET cDonde = "Buscando y bloque precodigo Único";
			SELECT id, precodigo INTO nIdPreCodigoReal, cPecodigoReal
			  FROM cdx_precodigos where id_campaign = nIdCampaign and status = '3' limit 1 for update;
			  
			SET cDonde = "Precodigo Único con estado = 0, preparado para ser utilizado";
			UPDATE cdx_precodigos 
			   SET status = '0'
				  ,modified_by = v_user
			 WHERE id = nIdPreCodigoReal;
			-- ----------
			-- ----------
			Commit;
			-- ----------
			-- ----------
        ELSE
			set v_retTxt = 'PRECODIGO Sin códigos libres';
			SIGNAL ex_controladas;
        End IF;
	ELSE
		IF nExiste = 0 THEN
			SET cPecodigoReal = v_precodigo;
        ELSE
			set v_retTxt = 'PRECODIGO único erróneo';
			SIGNAL ex_controladas;
		END IF;
	END IF;
    
	-- -----------------------------------------------------------------------------------------------------
    -- Llamamos a la funcion real de PRECODIGOS que es de CDX
	-- -----------------------------------------------------------------------------------------------------
	SET cDonde = CONCAT("Llamando a -cdx_valida_precodigo- con precodigo: ", cPecodigoReal);
	Call cdx_valida_precodigo(v_idApp, v_user, v_retNum, v_retTxt, v_modulo, cPecodigoReal, v_fecha, v_url, v_idFrontal, v_idCatalogo, v_idCampaign, v_idCanje, v_idParticipante, v_idPrecodigo);
    
	IF cPecodigoReal != v_precodigo and v_idCampaign != nIdCampaign THEN
		set v_retTxt = concat('Ha habido algún problema con el Precódigo: ', cPecodigoReal, ' - ', v_precodigo, ' y la camapaña: ', v_idCampaign, ' - ', nIdCampaign);
		SIGNAL ex_controladas;
	END IF;

END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`g_calc_caducidad`( IN    v_idApp 		BIGINT  
																  , IN    v_user 		VARCHAR(45)		-- Usuario que lanza el procedimiento
																  , INOUT v_retNum 		INT				-- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
																  , INOUT v_retTxt 		VARCHAR(4000)	-- Texto en caso de error (v_retNum < 0)
																  , IN    v_fecha 		VARCHAR(19)		-- '%Y-%m-%d' Si no llega, se indica NOW()
																  , OUT   v_fec_Caduca	VARCHAR(19)		-- '%Y-%m-%d'
																  )
BEGIN
/*
Retorna el número de dias que a la fecha dada te quedan para caducar. En el caso de que la parametrización
sean meses, devolverá los días paramtrizados mas los dias del mes actual hasta el 1 del mes siguiente
*/
DECLARE dFecha			DATE;
DECLARE nUnidadesMes	INT;
DECLARE nidConcepto		BIGINT;  
DECLARE nPuntos			DECIMAL(11,2);
DECLARE nidMov			BIGINT;

DECLARE cMedida			VARCHAR(10);
DECLARE cUnidades		VARCHAR(10);
DECLARE nUnidades		INT;
DECLARE xLabel 			VARCHAR(250);
DECLARE xTooltip 		VARCHAR(250);
        
DECLARE xIdMovCad		BIGINT;
DECLARE xnSaldoCliente	DECIMAL(11,2);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio g_calc_caducidad';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
    IF v_fecha IS NOT NULL THEN
		Select g_fecha_ok(v_fecha , '%Y-%m-%d', 'N') into v_retTxt;
		IF v_retTxt is not null THEN
			SIGNAL ex_controladas;
		END IF;

		Select str_to_date(v_fecha,'%Y-%m-%d') into dFecha;
    ELSE
		Select date_format(now(),'%Y%m%d') into dFecha;
    END IF;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------    
		SET cDonde 			= 'Llamada a configuración 1';
		CALL hxxi_configuracion( v_idApp , v_user , v_retNum , v_retTxt , NULL , 'caducidad', 'medida' , cMedida , xLabel , xTooltip); 
		IF v_retNum != 0  THEN 
			SIGNAL ex_controladas;
		END IF;
        
		SET cDonde 			= 'Llamada a configuración 2';
		CALL hxxi_configuracion( v_idApp , v_user , v_retNum , v_retTxt , NULL , 'caducidad', 'unidades' , cUnidades , xLabel , xTooltip); 
		IF v_retNum != 0  THEN 
			SIGNAL ex_controladas;
		END IF;
        SET cDonde 			= 'Convirtiendo unidades';
		SET nUnidades = cUnidades;  -- Si no es correcto, dará error

		IF cMedida = 'dias' THEN
			select  DATE_ADD(dFecha, INTERVAL nUnidades DAY) into v_fec_Caduca;
        ELSE
			SET v_fec_Caduca = Last_day(dFecha);
			select  DATE_ADD(v_fec_Caduca, INTERVAL nUnidades MONTH) into v_fec_Caduca;
        END IF;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`g_calc_fecha_caducidad`( IN    v_idApp 	BIGINT  
																 						, IN    v_user 		VARCHAR(45)		-- Usuario que lanza el procedimiento
																						, INOUT v_retNum 	INT				-- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
																						, INOUT v_retTxt 	VARCHAR(4000)	-- Texto en caso de error (v_retNum < 0)
																						, IN    v_idParticipante	BIGINT     		-- beneficiario a conocer su saldo a caducar
																						, IN    v_fecha 	VARCHAR(19)		-- '%Y-%m-%d' fecha en la que se haría la caducidad. Si no se pone nada coge la próxima caducidad
																						, OUT   v_fCorteCad	VARCHAR(19)		-- '%Y-%m-%d' 
																						)
BEGIN
DECLARE nidConcepto		BIGINT;  
DECLARE nPuntos			DECIMAL(11,2);
DECLARE nidMov			BIGINT;

DECLARE cMedida			VARCHAR(10);
DECLARE cUnidades		VARCHAR(10);
DECLARE nUnidades		INT;
DECLARE xLabel 			VARCHAR(250);
DECLARE xTooltip 		VARCHAR(250);
        
DECLARE xIdMovCad		BIGINT;
DECLARE xnSaldoCliente	DECIMAL(11,2);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_crea_caduca';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- si no viene fecha, se coge de configuración
	IF v_fecha is null THEN
		SET cDonde 			= 'Llamada a configuración 1';
		CALL hxxi_configuracion( v_idApp , v_user , v_retNum , v_retTxt , NULL , 'caducidad', 'medida' , cMedida , xLabel , xTooltip); 
		IF v_retNum != 0  THEN 
			SIGNAL ex_controladas;
		END IF;
        
		SET cDonde 			= 'Llamada a configuración 2';
		CALL hxxi_configuracion( v_idApp , v_user , v_retNum , v_retTxt , NULL , 'caducidad', 'unidades' , cUnidades , xLabel , xTooltip); 
		IF v_retNum != 0  THEN 
			SIGNAL ex_controladas;
		END IF;
        SET cDonde 			= 'Convirtiendo unidades';
		SET nUnidades = cUnidades;  -- Si no es correcto, dará error
        
        SET cDonde 			= 'Calculando fecha por defecto caducidad';
		select date_format(CURDATE(),'%Y-%m-%d') into v_fCorteCad;
        -- v_fCorteCad hay que calcularlo con el los movimientos pendientes de caducar el participante
        
        
        IF cMedida = 'dias' THEN
			select  DATE_ADD(date_format(CURDATE(),'%Y-%m-%d'), INTERVAL nUnidades DAY) into v_fCorteCad;
        ELSE
			SET v_fCorteCad = date_format(g_primer_dia(CURDATE()),'%Y-%m-%d');
			select  DATE_ADD(v_fCorteCad, INTERVAL nUnidades MONTH) into v_fCorteCad;
        END IF;
	ELSE
		SET v_fCorteCad = v_fecha;
    END IF;
    
    -- comprobamos formato de la fecha
    Select g_fecha_ok(v_fCorteCad , '%Y-%m-%d', 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
    END IF;
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `madre`.`g_cdx_extrae_campo`(v_Campo		varchar(100)
																	, v_json_datos	varchar(4000)
																	) RETURNS varchar(4000) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
BEGIN
DECLARE cReturn		varchar(4000);
DECLARE cValor		varchar(4000);
DECLARE cTipo 		char(1);



DECLARE errorNum    varchar(4000);
DECLARE errorText   varchar(4000);

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de CURSORES
-- -----------------------------------------------------------------------------------------------------
DECLARE bFinCursor INT DEFAULT FALSE;



DECLARE cur1 CURSOR FOR 
	SELECT JSON_VALUE(v_json_datos, concat('$.', JSON_VALUE(JSON_KEYS(v_json_datos), CONCAT('$[', seq, ']')),'.valor'))	as valor
	  FROM seq_0_to_100000000 
	 WHERE seq < JSON_LENGTH(JSON_KEYS(v_json_datos))
	   AND JSON_VALUE(JSON_KEYS(v_json_datos), CONCAT('$[', seq, ']')) = v_Campo;  

DECLARE CONTINUE HANDLER FOR NOT FOUND SET bFinCursor = TRUE;


-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT;
		
        RETURN substr(CONCAT('Error de Sistema, contacte con su administrador: (', errorNum, ') - ', errorText), 1, 4000);
	End;
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	SET cReturn = null;

    OPEN cur1;
	bucle:LOOP 
		SET bFinCursor = false;
		FETCH cur1  into cValor;
        IF bFinCursor THEN
			LEAVE bucle;
        END IF;
        
        SET cReturn = cValor;
	END LOOP;
    CLOSE cur1;

	RETURN cReturn;
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `madre`.`g_fecha_ok`(v_fecha 		VARCHAR(250)    -- Cadena con la fecha
							 , v_formato 	VARCHAR(250)    -- formato en el que dee venir: '%Y-%m-%d' o '%Y-%m-%d %H:%i:%s',...
                             , v_nula		CHAR(1) 		-- "S" puede ser nula, cualquier otro valor, no puede
							 ) RETURNS varchar(4000) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
BEGIN
DECLARE cReturn		varchar(4000);
DECLARE dfecha		timestamp;

DECLARE errorNum    varchar(4000);
DECLARE errorText   varchar(4000);

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT;
		
        RETURN substr(CONCAT('Error de Sistema, contacte con su administrador: (', errorNum, ') - ', errorText), 1, 4000);
	End;
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	SET cReturn = null;
   	IF v_fecha is null and IFNULL(v_nula, 'N') != 'S' THEN
		set cReturn = 'La fecha no puede ser nula';
    END IF;
    select STR_TO_DATE(v_fecha, v_formato) into dfecha;
   	IF dfecha is null THEN
		set cReturn = CONCAT('La fecha ', v_fecha, ' no tiene formato "', v_formato, '"');
    END IF;

RETURN cReturn;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`g_mov_busca_cncpt`( IN v_idApp 			BIGINT  
																	, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
																	, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																	, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                                    , IN    v_grupo			varchar(50)
                                                                    , IN    v_nombre		varchar(50)
                                                                    , IN    v_cCncpt		CHAR(1)
																	, INOUT v_idConcepto	BIGINT 
																	)
BEGIN
DECLARE cCncpt			CHAR(1);
DECLARE xLabel 			VARCHAR(250);
DECLARE xTooltip 		VARCHAR(250);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio g_mov_busca_cncpt';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	IF v_idConcepto IS NULL THEN
		-- Primero lo que llega debe tener valor, el Id_concepto de la tabla de conceptos para la aplicación que estamos tratando
		CALL hxxi_configuracion( v_idApp , v_user , v_retNum , v_retTxt , NULL , v_grupo, v_nombre , v_idConcepto , xLabel , xTooltip); 
		IF v_retNum != 0  THEN 
			SIGNAL ex_controladas;
		END IF;
	        
		IF IFNULL(v_idConcepto, 0) = 0  THEN 
			set v_retTxt = 'No se dispone de Concepto de operacion para realizar el movimiento';
			SIGNAL ex_controladas;
		END IF;
	END IF;
	    
	-- con un concepto ya podemos recoger valores y controlar que exista y validar el concepto
	SET cCncpt = '-';  -- B --> Suma/Resta   ;    U --> Canje    ;   A --> Anulación    ;   C	Caducidad
    SELECT tipo, id INTO cCncpt, v_idConcepto FROM mov_conceptos  WHERE id_concepto = v_idConcepto AND id_app = v_idApp;
    IF IFNULL(cCncpt, '-') = '-' THEN
		set v_retTxt = concat('El Concepto ', IFNULL(v_idConcepto, '?'),' no existe para la APP ', v_idApp);
		SIGNAL ex_controladas;
	END IF;

    IF cCncpt != v_cCncpt THEN
		set v_retTxt = concat('El Concepto indicado ', v_idConcepto,' para la APP ', v_idApp, ' tiene el tipo concepto ', cCncpt, ' y debería ser de tipo "', v_cCncpt, '"');
		SIGNAL ex_controladas;
	END IF;
	SET v_retNum = 0;
    -- ---------------------------------------------------------------------------------------------------------------------------
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `madre`.`g_primer_dia`(v_dia datetime) RETURNS date
    DETERMINISTIC
BEGIN
  RETURN DATE_ADD(LAST_DAY(DATE_SUB(v_dia, INTERVAL 1 MONTH)), INTERVAL 1 DAY);
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `madre`.`g_texto`(v_texto_defecto 	VARCHAR(4000)  
														, v_idApp			BIGINT 
                                                        ) RETURNS varchar(4000) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
BEGIN
DECLARE cReturn		varchar(4000);

DECLARE errorNum    varchar(4000);
DECLARE errorText   varchar(4000);

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT;
		
        RETURN v_texto_defecto;
	End;
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	-- SELECT g_texto(null, v_texto_defecto, v_idApp, null) INTO cReturn;
    SET cReturn = v_texto_defecto;

RETURN cReturn;
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `madre`.`g_texto_def`(v_texto_defecto 	VARCHAR(4000)  
														, v_idApp	BIGINT -- Obligatorio si no introduce el idioma
														, v_Idioma	BIGINT -- Obligatorio si no introduce el id_app
														) RETURNS varchar(4000) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
BEGIN
DECLARE cReturn		varchar(4000);

DECLARE errorNum    varchar(4000);
DECLARE errorText   varchar(4000);

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT;
		
        RETURN v_texto_defecto;
	End;
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
	SET cReturn = v_texto_defecto;

RETURN cReturn;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`hxxi_configuracion`( IN v_idApp 	BIGINT  
															, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
															, INOUT v_retNum 		INT             -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt 		VARCHAR(4000)   -- Texto en caso de error (v_retNum < 0)
															, IN  v_id				BIGINT			-- opcional si viene grupo y mombre
															, IN  v_grupo		 	VARCHAR(250)  COLLATE utf8mb4_unicode_ci  -- Opcional si viene id, pero debe venir nombre
															, IN  v_nombre 			VARCHAR(250)  COLLATE utf8mb4_unicode_ci  -- Opcional si viene id, pero debe venir grupo
															, OUT v_valor   		VARCHAR(4000)
															, OUT v_label 			VARCHAR(255)  
															, OUT v_tooltip 		VARCHAR(255)  
															)
BEGIN

DECLARE cGrupo	VARCHAR(250)  COLLATE utf8mb4_unicode_ci;
DECLARE cNombre	VARCHAR(250)  COLLATE utf8mb4_unicode_ci;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio hxxi_configuracion';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = -2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
    -- Si tiene ID buscamos por ID
	SET cDonde  = 'hxxi_configuracion.Claves1';
	IF IFNULL(v_id, 0) != 0  THEN 
		SET cDonde  = 'hxxi_configuracion.Claves2';
		Select valor, label , tooltip into v_valor , v_label , v_tooltip from hxxi_configuracion where id_app = v_idApp and id = v_id;
		IF row_count() != 1 then
			set v_retTxt = CONCAT('NO se encuentra valor de configuración para el ID "', v_id, '" de la App "', v_idApp, '".');
			SIGNAL ex_controladas;
		END IF;
	ELSE
		SET cDonde  = 'hxxi_configuracion.Claves3';
		IF IFNULL(v_grupo, '_') != '_' AND IFNULL(v_nombre, '_') != '_'  THEN 
			SET cGrupo	= v_grupo;
			SET cNombre	= v_nombre;
			SET cDonde  = 'hxxi_configuracion.Claves4';
			Select valor , label , tooltip into v_valor, v_label , v_tooltip 
              from hxxi_configuracion 
			 where id_app = v_idApp 
               and grupo  = cGrupo
               and nombre = cNombre;
			IF row_count() != 1 then
				set v_retTxt = CONCAT('NO se encuentra valor de configuración para el grupo "', v_grupo, '" y el nombre "', v_nombre, '" de la App "', v_idApp, '".');
				SIGNAL ex_controladas;
			END IF;
		ELSE
			set v_retTxt = 'Error de parámetros. O llega v_id o llega el nombre y el grupo';
			SIGNAL ex_controladas;
		END IF;
	END IF;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`hxxi_crea_log`( IN    v_idApp BIGINT          -- (Valor nulo --> 0)   
															, IN    v_tipo VARCHAR(1)       -- (Otro valor o nulo --> "E") 'A' --> Aviso;  'E' --> Error; 'I' --> Incidencia. 
															, IN    v_accion CHAR(1)        -- (otro valor o nulo --> "2") 0 --> No ha roto el proceso ni la función en la que se ejecuta; 1 --> la función que se ejecuta, se ha quedado a medias en algún lugar; 2 --> se ha debido romper el proceso
															, IN    v_user VARCHAR(45)      -- Usuario que lanza el procedimiento
															, IN    v_RETURNED_SQLSTATE VARCHAR(4000)
															, IN    v_MESSAGE_TEXT VARCHAR(4000)
															, IN    v_MYSQL_ERRNO VARCHAR(4000)
															, IN    v_Log VARCHAR(4000)     
															, INOUT v_retNum INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0))
															)
BEGIN
DECLARE errorMySql    varchar(4000);
DECLARE cLog          varchar(4000);

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
            SET v_retNum = -1;
			SET v_retTxt = ifnull(v_retTxt, CONCAT('Error de sistema, contacte con su administrador. REF: ', date_format(CURTIME(), '%Y%m%d%h%i%s')));
	End;
-- -----------------------------------------------------------------------------------------------------
-- ----------------------------------------------------------------------------------------------------- 

    SET cLog       = v_log;
	SET v_retNum   = ifnull(v_retNum, -1);
	SET v_retTxt   = ifnull(v_retTxt, CONCAT('Error de sistema, contacte con su administrador. REF: ', date_format(CURTIME(), '%Y%m%d%h%i%s')));

	IF v_Log is null Then
		SET cLog       = v_retTxt;
    END IF;
	IF ifnull(v_tipo,'E') not in ('A', 'E', 'I') Then
		SET cLog       = substr(concat('Tipo: ', ifnull(v_tipo,'_'), ' - ', clog), 1, 4000);
    END IF;
	IF ifnull(v_accion,'2') not in ('0', '1', '2') Then
		SET cLog       = substr(concat('Accion: ', ifnull(v_accion,'_'), ' - ', clog), 1, 4000);
    END IF;
	insert into hxxi_log (id_app,            tipo,               accion,   log,   err_mysql,     error_num,           error_text,     modified_by) 
				  values (ifnull(v_idApp,0), ifnull(v_tipo,'E'), ifnull(v_accion,'2'), cLog, v_MYSQL_ERRNO, v_RETURNED_SQLSTATE, v_MESSAGE_TEXT, substr(v_user,45));

END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`hxxi_crea_participante`( IN    v_idApp BIGINT  
                                                            , IN    v_user 		VARCHAR(45)      -- Usuario que lanza el procedimiento
                                                            , INOUT v_retNum 	INT            -- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
                                                            , INOUT v_retTxt 	VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                            , OUT v_idParticipante BIGINT		-- Retorna el ID del participante creado, si ya existiera el email devuelve también su ID
                                                            , IN v_nombre		VARCHAR(40)
                                                            , IN v_apellidos	VARCHAR(60)
                                                            , IN v_email		VARCHAR(255)	-- Valor por el que se busca al participante
                                                            , IN v_username		VARCHAR(100)
                                                            , IN v_telefono		VARCHAR(15)
                                                            , IN v_direccion	VARCHAR(255)
                                                            , IN v_zipcode		VARCHAR(15)
                                                            , IN v_provincia	VARCHAR(100)
                                                            , IN v_pais			VARCHAR(100)
                                                            )
BEGIN
DECLARE nExiste			INT;
DECLARE cUserName       varchar(100) default v_username;
DECLARE cPWD	        varchar(100);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio hxxi_crea_participante';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
            
		SET v_retNum = -2;
		Call hxxi_crea_log(v_idApp , 'A', '1', v_user, errorNum, errorText, errorMySql, concat(cDonde, '. MiError3'),  v_retNum, v_retTxt); 
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	IF v_email is NULL THEN -- Comprobar que sea un email
        set v_retTxt = 'El email no puede ser nulo';
		SIGNAL ex_controladas;
	END IF;
	IF v_idApp is NULL THEN 
        set v_retTxt = 'La apliación no puede ser nula';
		SIGNAL ex_controladas;
	END IF;

    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = Concat('Select ', v_email, '. ID: ', v_idApp);
    SELECT count(*)  INTO nExiste
      FROM hxxi_participantes 
	 WHERE email COLLATE utf8mb4_unicode_ci = v_email
       AND id_app = v_idApp;

    SET cDonde = Concat('Select ', v_email, '. ID: ', v_idApp, 'Existe: ', nExiste);
    -- IF ifnull(v_idParticipante, 0) = 0 THEN 
    IF nExiste = 0 THEN 
		IF cUserName is null THEN 
			select LEFT(UUID(), 8) into cUserName;
		END IF;
		select LEFT(UUID(), 12) into cPWD;
        SET cDonde = 'Insertando';
		INSERT INTO hxxi_participantes(id_app,  nombre,   apellidos,   email,   username,  password, telefono,   direccion,   zipcode,   provincia,   pais,   status, modified_by)
								VALUES(v_idApp, v_nombre, v_apellidos, v_email, cUserName, cPWD,     v_telefono, v_direccion, v_zipcode, v_provincia, v_pais, 1,      v_User);
		SELECT @@identity AS id into v_idParticipante;
		SET v_retNum = 0;
        SET v_retTxt = 'Registro creado correctamente.';
    ELSE
		SELECT id  INTO v_idParticipante
		  FROM hxxi_participantes 
		 WHERE email COLLATE utf8mb4_unicode_ci = v_email
		   AND id_app = v_idApp;
           
		SET v_retNum = 1;
        SET v_retTxt = 'El Email ya existía, no se ha creado ni modificado el participante';
		SET cDonde = Concat(v_retTxt, ' - Select ', v_email, '. ID: ', v_idApp);
    END IF;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_caducidad`( IN    v_idApp 			BIGINT  
																 , IN    v_user 			VARCHAR(45)      -- Usuario que lanza el procedimiento
																 , INOUT v_retNum 		INT            -- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
																 , INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																 , IN  v_idParticipante 	BIGINT          -- Por si se queire cadudcar un único beneficiario
																 , IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d' fecha de caducidad. De aquí hacia atrás se caduca todo
																 , IN  v_descripcion 	VARCHAR(250)    -- parte común de la Descripción para las operaciones de caducidad. NO ES OBLIGATORIO
																 , OUT v_saldoCaducado	DECIMAL(12,2)   -- Saldp total caducado
																 )
BEGIN
/*
A esta función solo la puede llamar W_MOC_CADUCIDAD porque es simplemente para aligerar el procedimiento y dejarlo mas claro y realizar
*/
DECLARE nPuntos			 DECIMAL(11,2);
DECLARE nPuntosCaducados DECIMAL(11,2);
DECLARE nIdTotales		 BIGINT;
DECLARE nIdParticipante	 BIGINT;
DECLARE dfecha			 DATE;
-- DECLARE nSalto			 int default 10;
-- DECLARE nContador		 int;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_caducidad';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';
DECLARE ex_errores     CONDITION FOR SQLSTATE '45001';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de CURSORES
-- -----------------------------------------------------------------------------------------------------
DECLARE bFinCursor INT DEFAULT FALSE;

DECLARE cur1 CURSOR FOR 
	SELECT id, id_participante, saldo nPuntos
	  FROM hxxi_participantes_totales 
	 where id_participante = IFNULL(v_idParticipante, id_participante)
       and saldo > 0;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET bFinCursor = TRUE;

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION, ex_errores
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	SET cDonde   = 'Validaciones';
   	IF v_fecha is null THEN
		set v_retTxt = 'La fecha no peude ser nula';
		SIGNAL ex_controladas;
    END IF;
    select STR_TO_DATE(v_fecha, '%Y-%m-%d') into dfecha;
   	IF dfecha is null THEN
		set v_retTxt = CONCAT('La fecha ', v_fecha, ' no tiene formato "aaaa-mm-dd"');
		SIGNAL ex_controladas;
    END IF;
   	IF v_descripcion is null THEN
		SET v_descripcion = CONCAT('Caducidad a ', v_fecha);
    END IF;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'update para FIFO ID. Abrimos curso';
 -- 	salto:LOOP 
 -- 		SET nContador = nSalto;
 		OPEN cur1;
		bucle:LOOP 
			SET bFinCursor = false
			  , cDonde 	   = 'leemos cursor';
			FETCH cur1    into nIdTotales, nIdParticipante, nPuntos;
			IF bFinCursor THEN
				LEAVE bucle;
			END IF;
 --         SET nContador = nContador - 1;
 -- 		IF nContador = 0 THEN
 -- 			LEAVE bucle;
 -- 		END IF;

			SET cDonde 	   = 'Llamada a Caducidad Beneficiario';
			CALL mov_crea_caduca( v_idApp, v_user , v_retNum , v_retTxt , nIdParticipante , v_fecha , v_descripcion , nPuntosCaducados);
			IF v_retNum != 0 THEN
				SIGNAL ex_controladas;
			END IF;
			IF nPuntosCaducados > nPuntos THEN -- No se puede caducar mas del saldo del usuario, error grabe
				set v_retTxt = CONCAT('El usuario ', nIdParticipante, ' Tiene un saldo de ', nPuntos, ' Puntos y la función a caducar retorna ', nPuntosCaducados)
                  , cDonde   = 'Llamada a MOV_CREA_CADUCA';
				SIGNAL ex_controladas;
			END IF;
		END LOOP;
		CLOSE cur1;
        
 -- 		IF nContador = nSalto THEN
 -- 			LEAVE salto;
 -- 		END IF;
 -- 	END LOOP; -- Salto
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_consulta_a_caducar`( IN     v_idApp 			BIGINT  
																 		, IN    v_user 				VARCHAR(45)		-- Usuario que lanza el procedimiento
																		, INOUT v_retNum 			INT				-- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
																		, INOUT v_retTxt 			VARCHAR(4000)	-- Texto en caso de error (v_retNum < 0)
																		, IN    v_idParticipante	BIGINT     		-- beneficiario a conocer su saldo a caducar
																		, IN    v_fecha 			VARCHAR(19)		-- '%Y-%m-%d' fecha en la que se haría la caducidad. Si no se pone nada coge fin de mes actual (1 del siguiente)
																		, OUT   v_saldoACaducar		DECIMAL(12,2)	-- Saldp total caducado
																		)
BEGIN
DECLARE nPuntos			DECIMAL(11,2);
DECLARE fCorteCad       date;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_consulta_a_caducar';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de CURSORES
-- -----------------------------------------------------------------------------------------------------
DECLARE bFinCursor INT DEFAULT FALSE;

DECLARE cur1 CURSOR FOR 
	SELECT puntos - (anulado + caducado + utilizado) PuntosCaducar
	  FROM mov_movimientos 
	 INNER JOIN mov_conceptos on mov_movimientos.id_concepto = mov_conceptos.id
	 where id_participante = v_idParticipante
       and mov_conceptos.tipo = 'B'     
       and (puntos - (anulado + caducado + utilizado)) > 0 -- Todavía quedan puntos pendientes de anular
       and fec_caducidad <= fCorteCad
	order by mov_movimientos.id asc;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET bFinCursor = TRUE;

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
    IF v_fecha is null then
        SELECT LAST_DAY(now()) into fCorteCad;
    ELSE
		-- comprobamos formato de la fecha
		Select g_fecha_ok(v_fecha , '%Y-%m-%d', 'N') into v_retTxt;
		IF v_retTxt is not null THEN
			SIGNAL ex_controladas;
		END IF;
		SELECT date_format(v_fecha,'%Y-%m-%d') into fCorteCad;
    END IF;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde 			= 'Proceso Calculo'
      , v_saldoACaducar = 0;
    OPEN cur1;
	bucle:LOOP 
		SET bFinCursor = false
		  , cDonde 	   = 'leemos cursor';
		FETCH cur1    into nPuntos;
        IF bFinCursor THEN
			LEAVE bucle;
        END IF;
        SET v_saldoACaducar = v_saldoACaducar + nPuntos;
	END LOOP;
    CLOSE cur1;
    SET v_retTxt = concat('El saldo a caducar para fecha ', fCorteCad, ' es de ', v_saldoACaducar);
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_crea`( IN    v_idApp 			BIGINT  
                                                      , IN    v_user 			VARCHAR(45)      -- Usuario que lanza el procedimiento
                                                      , INOUT v_retNum 			INT            -- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
                                                      , INOUT v_retTxt 			VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                      , IN  v_idParticipante 	BIGINT          -- 
													  , IN  v_idCentro 			BIGINT          -- 
													  , IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
													  , IN  v_idConcepto 		BIGINT          -- 
													  , IN  v_descripcion 		VARCHAR(250)    -- 
													  , IN  v_puntos 			DECIMAL(11,2)   -- 
													  , IN  v_idMov				BIGINT          -- ID del movimiento origen, en caso de anulaciones, etc..
													  , IN  v_fichero 			VARCHAR(250)    -- 
													  , OUT v_id   				BIGINT          -- ID de la operación creada
													  , OUT v_saldo 			DECIMAL(11,2)   -- 
                                                      )
BEGIN

DECLARE nExiste			int;
DECLARE dFecha			datetime;
DECLARE nSaldo 			DECIMAL(11,2);
DECLARE cCncpt			CHAR(1);
DECLARE cFecCaducidad	Varchar(19);
DECLARE dCaducidad		DATE;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_crea';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		-- SELECT '2-',v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, v_idCentro, dFecha, v_descripcion, v_puntos, v_fichero, v_id, v_saldo;

		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	SET v_retNum = 0;
    SET v_retTxt = 'Registro creado correctamente.';

	IF v_user is null THEN 
        set v_retTxt = 'Debe indicar un Usuario respponsable creador del movimiento';
		SIGNAL ex_controladas;
	END IF;

	IF IFNULL(v_idParticipante, 0) = 0 THEN 
        set v_retTxt = 'Debe indicar un id de participante';
		SIGNAL ex_controladas;
	else
        SELECT count(id)  INTO nExiste   FROM hxxi_participantes  WHERE id = v_idParticipante   AND id_app = v_idApp;
        IF nExiste = 0 Then
			set v_retTxt = 'El participante no existe';
			SIGNAL ex_controladas;
        END IF;
	END IF;
    
	set dFecha = str_to_date(v_fecha, '%Y-%m-%d %H:%i:%s');
	IF v_fecha is null THEN 
        set v_retTxt = 'Debe indicar una fecha';
		SIGNAL ex_controladas;
	END IF;
	IF IFNULL(v_idConcepto, 0) = 0 THEN 
        set v_retTxt = 'Debe indicar un id de Concepto';
		SIGNAL ex_controladas;
	END IF;
	IF v_descripcion is null THEN 
        set v_retTxt = 'Debe indicar una descripción';
		SIGNAL ex_controladas;
	END IF;

	SET cCncpt = '-';
    SELECT tipo INTO cCncpt FROM mov_conceptos  WHERE id = v_idConcepto;
    IF IFNULL(cCncpt, '-') = '-' THEN
		set v_retTxt = concat('El Concepto ', IFNULL(v_idConcepto, ' '),' no existe.');
		SIGNAL ex_controladas;
	END IF;

	-- PDTE. Validaciones que solo venga en determinados tipos de movimientos
	IF IFNULL(v_idMov, 0) != 0 THEN 
        SELECT count(id)  INTO nExiste   FROM mov_movimientos  WHERE id = v_idMov  AND id_app = v_idApp;
        IF nExiste = 0 Then
			set v_retTxt = 'Se identifica como origen un movimiento que no existe';
			SIGNAL ex_controladas;
        END IF;
	END IF;
    
    -- Validar que tiene saldo sufienciente en caso de resta
    SET cDonde = 'Buscando saldo';
    Select saldo + v_puntos into nSaldo from hxxi_participantes_totales  WHERE id_participante = v_IdParticipante;
    select row_count() into nExiste;
    IF nExiste = 0 THEN
		SET nSaldo = v_puntos;
    END IF;
    IF nSaldo < 0 THEN
		set v_retTxt = CONCAT('Esta operación (de ', v_puntos,' puntos) no se puede realizar porque se queda el saldo inferior a cero (', nSaldo, ').');
		SIGNAL ex_controladas;
    END IF;
    
    -- Calculando fecha de caducidad
	call g_calc_caducidad(v_idApp , v_user , v_retNum , v_retTxt , date_format(dFecha, '%Y-%m-%d'), cFecCaducidad);
    IF v_retNum != 0 THEN
		SIGNAL ex_controladas;
    END IF;
    select str_to_Date(cFecCaducidad, '%Y-%m-%d') into dCaducidad;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'Insertando';
    INSERT INTO mov_movimientos (id_app,  id_participante,  id_centro,  id_Mov,  fecha,  id_concepto,  descripcion,   puntos,   anulado, utilizado, caducado, saldo,  fec_caducidad, fichero,   modified_by)
					     VALUES (v_idApp, v_idParticipante, v_idCentro, v_idMov, dFecha, v_idConcepto, v_descripcion, v_puntos, 0,       0,         0,        nSaldo, dCaducidad,    v_fichero, v_user);
	SELECT @@identity AS id into v_id;
    
    -- Modificar Saldo
    IF nExiste = 0 then
		SET cDonde = 'insertando saldo';
		INSERT INTO hxxi_participantes_totales(id_participante,   saldo, utilizado, caducado, modified_by)
										VALUES(v_idParticipante, nSaldo, 0,         0,        v_user);
	ELSE
		SET cDonde = 'Modificando saldo';
		UPDATE hxxi_participantes_totales  
		   SET saldo 	 = nSaldo
              ,utilizado = case when cCncpt = 'U' then utilizado + ABS(v_puntos) else utilizado end
              ,caducado  = case when cCncpt = 'C' then caducado  + ABS(v_puntos) else caducado  end
         WHERE id_participante = v_IdParticipante;
     END IF;
     SET v_saldo = nSaldo;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_crea_anula`( IN v_idApp 		BIGINT  
															, IN v_user 			VARCHAR(45)    -- Usuario que lanza el procedimiento
															, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
															, IN  v_idParticipante 	BIGINT          -- 
															, IN  v_idMovOrigen		BIGINT         -- Movimiento que vamos a anular
															, IN  v_fecha 			VARCHAR(19)    -- '%Y-%m-%d %H:%i:%s'
															, IN  v_descripcion 	VARCHAR(250)   -- 
															, IN  v_puntos 			DECIMAL(11,2)  -- en positivo a anular
															, IN  v_fichero 		VARCHAR(250)   -- 
															, OUT v_id   			BIGINT         -- ID de la operación creada
															, OUT v_saldo 			DECIMAL(11,2)  -- 
															)
BEGIN
DECLARE nidConcepto		BIGINT;  
DECLARE nIdConceptoAux	BIGINT;  
DECLARE cCncpt			CHAR(1);

DECLARE nPuntos		DECIMAL(10,2);
DECLARE nAnulado	DECIMAL(10,2);
DECLARE nCaducado	DECIMAL(10,2);
DECLARE nUtilizado	DECIMAL(10,2);
DECLARE nConcepto	BIGINT;
DECLARE cTipo       char(1);
DECLARE nIdCentro	BIGINT;


-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_crea_anula';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	IF IFNULL(v_puntos, 0) <= 0  THEN 
        set v_retTxt = 'El proceso de anulación espera los movimientos en positivo';
		SIGNAL ex_controladas;
	END IF;
    SET cDonde   = 'Select movimiento';
    SELECT puntos,  anulado,  caducado,  utilizado,  id_concepto, Id_Centro 
	  into nPuntos, nAnulado, nCaducado, nUtilizado, nConcepto,   nIdCentro 
      FROM mov_movimientos where id = v_idMovOrigen and id_participante = v_idParticipante;
    IF row_count() != 1 then
        set v_retTxt = concat('El movimiento a anular ', v_idMovOrigen,'no existe para el participante ', v_idParticipante);
		SIGNAL ex_controladas;
    end if;
    IF nPuntos < v_puntos THEN
        set v_retTxt = concat('No se puede anular por ', v_puntos, ' porque el movimiento tiene ', nPuntos, ' Puntos');
		SIGNAL ex_controladas;
    end if;
    IF nPuntos < (nAnulado + nCaducado + nUtilizado + v_Puntos) THEN
        set v_retTxt = concat('No se puede anular por ', v_puntos, ' porque el movimiento tiene ', nPuntos, ' Puntos y la suma de anulaciones, caducidades y canjes es ', (nAnulado + nCaducado + nUtilizado));
		SIGNAL ex_controladas;
    end if;
    SET cDonde   = 'Select concepto';
    Select tipo into cTipo  from mov_conceptos where id_concepto = nConcepto and id_app = v_idApp;
    IF cTipo != 'B' and nPuntos > 0 THEN
        set v_retTxt = 'Solo de se pueden anular movimientos básicos positivos';
		SIGNAL ex_controladas;
    end if;
    
	-- ---------------------  Control de concepto  --------------------------------------------------------------------------
    -- Primero lo que llega debe tener valor, el Id_concepto de la tabla de conceptos para la aplicación que estamos tratando
	Select valor into nIdConceptoAux from hxxi_configuracion where id_app = v_idApp and grupo = 'movimientos' and nombre = 'anula';
        
	IF IFNULL(nIdConceptoAux, 0) = 0  THEN 
		set v_retTxt = 'No se dispone de Concepto de operacion para realizar el movimiento';
		SIGNAL ex_controladas;
	END IF;
    -- con un concepto ya podemos recoger valores y controlar que exista y validar el concepto
	SET cCncpt = '-';  -- B --> Suma/Resta   ;    U --> Canje    ;   A --> Anulación    ;   C	Caducidad
    SELECT tipo, id INTO cCncpt, nIdConcepto FROM mov_conceptos  WHERE id_concepto = nIdConceptoAux AND id_app = v_idApp;
    IF IFNULL(cCncpt, '-') = '-' THEN
		set v_retTxt = concat('El Concepto ', IFNULL(nIdConceptoAux, ' '),' no existe para la APP ', v_idApp);
		SIGNAL ex_controladas;
	END IF;
    IF cCncpt != 'A' THEN
		set v_retTxt = concat('El Concepto indicado ', nIdConceptoAux,' para la APP ', v_idApp, ' tiene el tipo concepto ', cCncpt, ' y debería ser de tipo "A"');
		SIGNAL ex_controladas;
	END IF;
    -- ---------------------------------------------------------------------------------------------------------------------------

    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'Llamando a CREA Movimiento';
	Call mov_crea( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, nIdCentro, v_fecha, nidConcepto, v_descripcion, -(v_puntos), v_idMovOrigen, v_fichero, v_id, v_saldo);
	IF v_retNum != 0 THEN 
		SIGNAL ex_controladas;
	END IF;
	
    SET cDonde = 'Llamando a FIFO Anula';
	Call mov_FIFO_anula( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, v_puntos, v_idMovOrigen,  v_id);
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_crea_caduca`( IN    v_idApp 		BIGINT  
																 , IN    v_user 		VARCHAR(45)    -- Usuario que lanza el procedimiento
																 , INOUT v_retNum 		INT            -- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
																 , INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																 , IN  v_idParticipante BIGINT         -- Por si se queire cadudcar un único beneficiario
																 , IN  v_fecha 			VARCHAR(19)    -- '%Y-%m-%d' fecha de caducidad. De aquí hacia atrás se caduca todo
																 , IN  v_descripcion 	VARCHAR(250)   -- parte común de la Descripción para las operaciones de caducidad
																 , OUT v_saldoCaducado	DECIMAL(12,2)  -- Saldp total caducado
																 )
BEGIN
DECLARE nidConcepto		BIGINT;  
DECLARE nPuntos			DECIMAL(11,2);
DECLARE nidMov			BIGINT;

DECLARE fCorteCad       date;
DECLARE xIdMovCad		BIGINT;
DECLARE xnSaldoCliente	DECIMAL(11,2);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_crea_caduca';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de CURSORES
-- -----------------------------------------------------------------------------------------------------
DECLARE bFinCursor INT DEFAULT FALSE;

DECLARE cur1 CURSOR FOR 
	SELECT mov_movimientos.id, puntos - (anulado + caducado + utilizado) PuntosCaducar
	  FROM mov_movimientos 
	 INNER JOIN mov_conceptos on mov_movimientos.id_concepto = mov_conceptos.id
	 where id_participante = v_idParticipante
       and mov_conceptos.tipo = 'B'     
       and (puntos - (anulado + caducado + utilizado)) > 0 -- Todavía quedan puntos pendientes de anular
       and fec_caducidad <= fCorteCad
	order by mov_movimientos.id asc
       FOR UPDATE;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET bFinCursor = TRUE;

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
    -- comprobamos formato de la fecha
    Select g_fecha_ok(v_fecha , '%Y-%m-%d', 'N') into v_retTxt;
    IF v_retTxt is not null THEN
		SIGNAL ex_controladas;
    END IF;

    select date_format(v_fecha,'%Y-%m-%d') into fCorteCad;
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde 			= 'Proceso caducidad'
      , v_saldoCaducado = 0;
    OPEN cur1;
	bucle:LOOP 
		SET bFinCursor = false
		  , cDonde 	   = 'leemos cursor';
		FETCH cur1    into nidMov, nPuntos;
        IF bFinCursor THEN
			LEAVE bucle;
        END IF;
        SET v_saldoCaducado = v_saldoCaducado + nPuntos;
        
		SET cDonde 		= 'Actualizamos mov_movimientos';           
		UPDATE mov_movimientos 
		   SET caducado		= caducado + nPuntos
			 , modified_by	= v_user
		 WHERE id			= nidMov;
	END LOOP;
    CLOSE cur1;

	-- -----------------------------------------------------------------------------------------------------------------------------------------------
    IF v_saldoCaducado != 0 THEN
		SET cDonde 	= 'Búsqueda de concepto caducidad';
		Call g_mov_busca_cncpt( v_idApp , v_user , v_retNum , v_retTxt , 'movimientos' , 'caduca' , 'C', nidConcepto);
		IF v_retNum != 0 THEN
			SIGNAL ex_controladas;
		END IF;

		SET cDonde 	= 'Creación movimiento caducidad';
		Call mov_crea( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, null, NOW(), nidConcepto, v_descripcion, -(v_saldoCaducado), null, null, xIdMovCad, xnSaldoCliente);
		IF v_retNum != 0 THEN 
			SIGNAL ex_controladas;
		END IF;
	END IF;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_crea_canje`( IN v_idApp 			BIGINT  
															, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
															, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
															, IN  v_idParticipante 	BIGINT          -- 
															, IN  v_idCentro 		BIGINT          -- 
															, IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
															, IN  v_descripcion 	VARCHAR(250)    -- 
															, IN  v_puntos 			DECIMAL(11,2)   -- Es el puntos de canje, por lo que debe ser positivo
															, IN  v_fichero 		VARCHAR(250)     -- 
															, OUT v_id   			BIGINT          -- ID de la operación creada
															, OUT v_saldo 			DECIMAL(11,2)   -- 
															)
BEGIN
DECLARE nidConcepto	BIGINT;   
DECLARE nidMov      BIGINT;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_crea_canje'; 
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	IF IFNULL(v_puntos, 0) > 0  THEN 
        set v_retTxt = 'Los puntos de una operación de canje no puede ser positivos';
		SIGNAL ex_controladas;
	END IF;
    
	-- ---------------------  Control de concepto  --------------------------------------------------------------------------
    SET cDonde 	= 'Búsqueda de concepto caducidad';
    Call g_mov_busca_cncpt( v_idApp , v_user , v_retNum , v_retTxt , 'movimientos' , 'canje' , 'U', nidConcepto);
    IF v_retNum != 0 THEN
		SIGNAL ex_controladas; 
	END IF;
    -- ---------------------------------------------------------------------------------------------------------------------------
    SET nidMov      = null; -- En los movimiento de canje no hay movimiento asociado

    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'Llamando a CREA Movimiento';
	Call mov_crea( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, v_idCentro, v_fecha, nidConcepto, v_descripcion, v_puntos, nidMov, v_fichero, v_id, v_saldo);
	IF v_retNum != 0 THEN 
		SIGNAL ex_controladas;
	END IF; 
	
    SET cDonde = 'Llamando a FIFO Anula';                                   --  Se positiviza
	Call mov_FIFO_canje( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, ABS(v_puntos), nidMov);
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_crea_resta`( IN v_idApp 			BIGINT  
															, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
															, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
															, IN  v_idParticipante 	BIGINT          -- 
															, IN  v_idCentro 		BIGINT          -- 
															, IN  v_idConcepto 		BIGINT          -- el id_concpeto de mov_conceptos para el Id_app actual
															, IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
															, IN  v_descripcion 	VARCHAR(250)    -- 
															, IN  v_puntos 			DECIMAL(11,2)   -- 
															, IN  v_fichero 		VARCHAR(250)     -- 
															, OUT v_id   			BIGINT          -- ID de la operación creada
															, OUT v_saldo 			DECIMAL(11,2)   -- 
															)
BEGIN
DECLARE nidConcepto	BIGINT default v_idConcepto;  
DECLARE nidMov		BIGINT;  

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_crea_resta';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	IF IFNULL(v_puntos, 0) > 0  THEN 
        set v_retTxt = 'En una resta los puntos no puede ser positivos';
		SIGNAL ex_controladas;
	END IF;
    
    -- ---------------------  Control de concepto  --------------------------------------------------------------------------
    SET cDonde 	= 'Búsqueda de concepto caducidad';
    Call g_mov_busca_cncpt( v_idApp , v_user , v_retNum , v_retTxt , 'movimientos' , 'resta' , 'A', nidConcepto);
    IF v_retNum != 0 THEN
		SIGNAL ex_controladas;
	END IF;
    -- ---------------------------------------------------------------------------------------------------------------------------
	IF IFNULL(v_idCentro, 0) = 0  THEN 
		Select valor into v_idCentro from hxxi_configuracion where id_app = v_idApp and grupo = 'general' and nombre = 'centro_defecto';
        
		IF IFNULL(v_idCentro, 0) = 0  THEN 
			set v_retTxt = 'No se dispone de centro para realizar el movimiento';
			SIGNAL ex_controladas;
		END IF;
	END IF;
    
    SET nidMov 		= Null; -- en la operaciones de acreditación normal, suma y resta, no hay ID movimiento ORIGEN

    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'Llamando a CREA Movimiento';
	Call mov_crea( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, v_idCentro, v_fecha, nidConcepto, v_descripcion, v_puntos, nidMov, v_fichero, v_id, v_saldo);
	IF v_retNum != 0 THEN 
		SIGNAL ex_controladas;
	END IF;
	
    SET cDonde = 'Llamando a FIFO Anula';                                   --  Se positiviza
	Call mov_FIFO_anula( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, -(v_puntos), nidMov, v_id);
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_crea_suma`( IN v_idApp 			BIGINT  
															, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
															, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
															, IN  v_idParticipante 	BIGINT          -- 
															, IN  v_idCentro 		BIGINT          -- 
															, IN  v_idConcepto 		BIGINT          -- el id_concpeto de mov_conceptos para el Id_app actual
															, IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
															, IN  v_descripcion 	VARCHAR(250)    -- 
															, IN  v_puntos 			DECIMAL(11,2)   -- 
															, IN  v_fichero 		VARCHAR(250)     -- 
															, OUT v_id   			BIGINT          -- ID de la operación creada
															, OUT v_saldo 			DECIMAL(11,2)   -- 
															)
BEGIN
DECLARE nidConcepto		BIGINT default v_idConcepto;  
DECLARE nidMov			BIGINT;  

DECLARE xLabel 			VARCHAR(250); 
DECLARE xTooltip 		VARCHAR(250);

DECLARE cSegundos		Varchar(15);
DECLARE nSegundos		INT;
DECLARE nExiste			INT;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql		varchar(4000);
DECLARE errorNum    	varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_crea_suma';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	IF IFNULL(v_puntos, 0) < 0  THEN 
        set v_retTxt = 'En una suma el puntos no puede ser negativo';
		SIGNAL ex_controladas;
	END IF;
    
	-- ---------------------  Control de concepto  --------------------------------------------------------------------------
    SET cDonde 	= 'Búsqueda de concepto caducidad';
    Call g_mov_busca_cncpt( v_idApp , v_user , v_retNum , v_retTxt , 'movimientos' , 'suma' , 'B', nidConcepto);
    IF v_retNum != 0 THEN
		SIGNAL ex_controladas;
	END IF;
    -- ---------------------------------------------------------------------------------------------------------------------------
        
	IF IFNULL(v_idCentro, 0) = 0  THEN 
		SET cDonde  = 'mov_crea_suma.Centro';
		-- Select valor into v_idCentro from hxxi_configuracion where id_app = v_idApp and grupo = 'general' and nombre = 'centro_defecto';
		CALL hxxi_configuracion( v_idApp , v_user , v_retNum , v_retTxt , NULL , 'general' , 'centro_defecto' , v_idCentro , xLabel , xTooltip); 
		IF v_retNum != 0  THEN 
			SIGNAL ex_controladas;
		END IF;
        
		IF IFNULL(v_idCentro, 0) = 0  THEN 
			set v_retTxt = 'No se dispone de centro para realizar el movimiento';
			SIGNAL ex_controladas;
		END IF;
	END IF;
    
    SET nidMov 		= Null; -- en la operaciones de acreditación normal, suma y resta, no hay ID movimiento ORIGEN
    
    -- -----------------------------------------------------------------------------------------------------
    -- No se pueden hacer dos canjes seguidos en menos de los X segundos planificados
    -- ----------------------------------------------------------------------------------------------------- 
	CALL hxxi_configuracion( v_idApp , v_user , v_retNum , v_retTxt , NULL , "movimientos", "suma_segundos" , cSegundos , xLabel , xTooltip); 
	IF v_retNum != 0  THEN 
		set cSegundos = '0'; -- SIGNAL ex_controladas;
	END IF;
	Select CAST(cSegundos AS UNSIGNED) into nSegundos;

	-- Aunque igual deberíamos buscar solo los movimientos de suma, vamos a tener en cuenta todos en una primera versión
	SELECT count(*) into nExiste FROM mov_movimientos a
     WHERE id_participante = v_IdParticipante 
       AND created_at > TIMESTAMPADD(SECOND,nSegundos*-1,now()) 
     ORDER BY id DESC LIMIT 1;
       
    SET cDonde = CONCAT("Segundos de intervalo: ", cSegundos, "Movimientos en menos tiempo: ", IFNULL(nExiste, 0));
    IF IFNULL(nExiste, 0) != 0 THEN
		set v_retTxt = "No se pueden realizar operaciones tan seguidas. Por favor, vuelva  intentarlo.";
		SIGNAL ex_controladas;
    END IF;   
   
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'Llamando a CREA Movimiento';
	Call mov_crea( v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, v_idCentro, v_fecha, nidConcepto, v_descripcion, v_puntos, nidMov, v_fichero, v_id, v_saldo);
    
	-- SET v_retNum = 0;
    -- SET v_retTxt = 'Registro creado correctamente.';
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_FIFO_anula`( IN    v_idApp 		BIGINT  
																, IN    v_user 			VARCHAR(45)      -- Usuario que lanza el procedimiento
																, INOUT v_retNum 		INT            -- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
																, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																, IN  v_idParticipante 	BIGINT          -- 
																, IN  v_puntos 			DECIMAL(11,2)   -- 
																, IN  v_idMovOrigen		BIGINT          -- ID del movimiento origen, en caso de anulaciones específicas de un movimiento, etc..
																, IN  v_idMovCreado		BIGINT  		-- Es el movimiento que se ha creado de anulación o resta
																)
BEGIN
DECLARE nExiste			int;
DECLARE dFecha			datetime;
DECLARE nSaldo 			DECIMAL(11,2);
DECLARE nPuntos			DECIMAL(11,2);
DECLARE nAnulado		DECIMAL(11,2);
DECLARE nCaducado		DECIMAL(11,2);
DECLARE nUtilizado		DECIMAL(11,2);
DECLARE nConcepto		int;
DECLARE cTipo			char(1);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_FIFO_anula';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
/**** 
		Aqui el error controlado se graba porque no se puede mostar al usuario
		Juntamos las dos opciones porque cualquier error aquí es un error de PROGRAMACION y GORDO, 
        no se puede continuar y ha que repasar datos y código      
****/
	Begin
		-- SET v_retNum = 2;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
    IF IFNULL(v_idParticipante, 0) = 0  THEN 
        set v_retTxt = 'El proceso FIFO siempre espera un beneficiario';
		SIGNAL ex_controladas;
	END IF;

    IF IFNULL(v_puntos, 0) = 0  THEN 
        set v_retTxt = 'El proceso FIFO siempre espera puntos a regularizar';
		SIGNAL ex_controladas;
	END IF;
   
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    IF IFNULL(v_idMovOrigen, 0) != 0  THEN 
		SET cDonde = 'Llamada a mov_FIFO_uno';
		CALL mov_FIFO_uno( v_idApp , v_user , v_retNum , v_retTxt , v_idParticipante , v_puntos , v_idMovOrigen, v_idMovCreado);
	ELSE
		SET cDonde = 'Llamada a mov_FIFO_varios: ';
		CALL mov_FIFO_varios( v_idApp , v_user , v_retNum , v_retTxt , v_idParticipante , v_puntos);
	END IF;
	IF v_retNum != 0 THEN 
		SET cDonde = concat('error: ', v_retNum ,' - ', v_retTxt);
		SIGNAL ex_controladas;
	END IF;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_FIFO_canje`( IN    v_idApp 			BIGINT  
																, IN    v_user 				VARCHAR(45)    -- Usuario que lanza el procedimiento
																, INOUT v_retNum 			INT            -- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
																, INOUT v_retTxt 			VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																, IN    v_idParticipante 	BIGINT         -- 
																, IN  	 v_puntos 			DECIMAL(11,2)  -- 
																, IN  	v_idMovCreado		BIGINT		   -- El el movimiento de canje creado, aunque no lo utilizaremos de momento
																)
BEGIN
DECLARE nExiste			int;
DECLARE dFecha			datetime;
DECLARE nSaldo 			DECIMAL(11,2);
DECLARE nPuntos			DECIMAL(11,2);
DECLARE nPuntosPendMov	DECIMAL(11,2);
DECLARE nPuntosPend		DECIMAL(11,2);
DECLARE nAnulado		DECIMAL(11,2);
DECLARE nCaducado		DECIMAL(11,2);
DECLARE nUtilizado		DECIMAL(11,2);
DECLARE cTipo			char(1);
DECLARE nidMov			BIGINT;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_FIFO_canje';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de CURSORES
-- -----------------------------------------------------------------------------------------------------
DECLARE bFinCursor INT DEFAULT FALSE;

DECLARE cur1 CURSOR FOR 
	SELECT mov_movimientos.id, puntos - (anulado + caducado + utilizado) nPuntosPendMov
	  FROM mov_movimientos 
	 INNER JOIN mov_conceptos on mov_movimientos.id_concepto = mov_conceptos.id
	 where id_participante = v_idParticipante
       and mov_conceptos.tipo = 'B'     
       and (puntos - (anulado + caducado + utilizado)) > 0 -- Todavía quedan puntos pendientes de anular
	order by mov_movimientos.id asc
       FOR UPDATE;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET bFinCursor = TRUE;

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'Consulta movimientos pendientes FIFO';
	SELECT sum(puntos),  sum(anulado),  sum(caducado),  sum(utilizado)
	  into 	  nPuntos, 	    nAnulado,      nCaducado,      nUtilizado
	  FROM mov_movimientos 
	 INNER JOIN mov_conceptos on mov_movimientos.id_concepto = mov_conceptos.id
	 where id_participante = v_idParticipante
       and mov_conceptos.tipo = 'B';
       
	IF row_count() != 1 then
		set v_retTxt = concat('No existen movimientos para hacer FIFO para el participante ', v_idParticipante);
		SIGNAL ex_controladas;
	end if;
	IF nPuntos < v_puntos THEN
		set v_retTxt = concat('No se puede realizar FIFO por ', v_puntos, ' porque los movimientos tienen ', nPuntos, ' Puntos');
		SIGNAL ex_controladas;
	end if;
	IF nPuntos < (nAnulado + nCaducado + nUtilizado + v_Puntos) THEN
		set v_retTxt = concat('No se puede realizar FIFO por ', v_puntos, ' porque los movimientos tienen ', nPuntos, ' Puntos y la suma de anulaciones, caducidades y canjes es ', (nAnulado + nCaducado + nUtilizado));
		SIGNAL ex_controladas;
	END IF;

    SET nPuntosPend =  v_puntos; -- Los puntos pendientes de "canjear FIFO" al inicio son los que nos envían
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'update CNJ para FIFO ID. Abrimos curso';
    OPEN cur1;
	bucle:LOOP 
		IF nPuntosPend <= 0 Then
			LEAVE bucle;
        END IF;
		SET bFinCursor = false
		  , cDonde 	   = 'leemos cursor';
		FETCH cur1    into nidMov, nPuntosPendMov;
        IF bFinCursor THEN
			LEAVE bucle;
        END IF;
        
		IF nPuntosPendMov <= nPuntosPend THEN  -- Tenemos puntos de sobrar, por lo que anulamos toda la operación
			SET nPuntos = nPuntosPendMov;
		ELSE  -- Tenemos mas puntos en la operacion que pendientes de FIFO, solo hay que marcar anulados con los pendientes generales, el resto ya se anularan con otra operación o caducaran
			SET nPuntos = nPuntosPend;
		END IF;
		SET nPuntosPend = nPuntosPend - nPuntosPendMov
           ,cDonde 		= 'Actualizamos CNJ mov_movimientos';
           
		UPDATE mov_movimientos 
		   SET utilizado	= utilizado + nPuntos
			 , modified_by	= v_user
		 WHERE id			= nidMov;
	END LOOP;
    CLOSE cur1;
       
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_FIFO_uno`( IN    v_idApp 			BIGINT  
															  , IN    v_user 			VARCHAR(45)      -- Usuario que lanza el procedimiento
															  , INOUT v_retNum 			INT            -- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
															  , INOUT v_retTxt 			VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
															  , IN    v_idParticipante 	BIGINT          -- 
															  , IN  v_puntos 			DECIMAL(11,2)   -- 
															  , IN  v_idMovOrigen		BIGINT          -- ID del movimiento origen
                                                              , IN  v_idMovCreado		BIGINT			-- El el movimiento que se ha generado apra anular los puntos
															  )
BEGIN
/*
A esta función solo la puede llamar mov_FIFO_Anula porque es simplemente para aligerar la función origen
*/
DECLARE nExiste			int;
DECLARE dFecha			datetime;
DECLARE nSaldo 			DECIMAL(11,2);
DECLARE nPuntos			DECIMAL(11,2);
DECLARE nAnulado		DECIMAL(11,2);
DECLARE nCaducado		DECIMAL(11,2);
DECLARE nUtilizado		DECIMAL(11,2);
DECLARE nConcepto		int;
DECLARE cTipo			char(1);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_FIFO_uno';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	SELECT puntos,  anulado,  caducado,  utilizado,  id_concepto
	  into nPuntos, nAnulado, nCaducado, nUtilizado, nConcepto
	  FROM mov_movimientos where id_app = v_idApp and id = v_idMovOrigen and id_participante = v_idParticipante;
	IF row_count() != 1 then
		set v_retTxt = concat('El movimiento a realizar FIFO ', v_idMovOrigen,'no existe para el participante ', v_idParticipante);
		SIGNAL ex_controladas;
	end if;
	IF nPuntos < v_puntos THEN
		set v_retTxt = concat('No se puede realizar FIFO por ', v_puntos, ' porque el movimiento tiene ', nPuntos, ' Puntos');
		SIGNAL ex_controladas;
	end if;
	IF nPuntos < (nAnulado + nCaducado + nUtilizado + v_Puntos) THEN
		set v_retTxt = concat('No se puede realizar FIFO por ', v_puntos, ' porque el movimiento tiene ', nPuntos, ' Puntos y la suma de anulaciones, caducidades y canjes es ', (nAnulado + nCaducado + nUtilizado));
		SIGNAL ex_controladas;
	end if;
	Select tipo into cTipo  from mov_conceptos where id_concepto = nConcepto and id_app = v_idApp;
	IF cTipo != 'B' and nPuntos > 0 THEN
		set v_retTxt = 'Solo de se pueden realizar FIFO en movimientos básicos positivos';
		SIGNAL ex_controladas;
	END IF;
    
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'update para FIFO ID';
    UPDATE mov_movimientos 
	   SET anulado		= anulado + v_puntos
		 , id_mov		= ifnull(id_mov, v_idMovCreado)
		 , modified_by	= v_user
     WHERE id			= v_idMovOrigen;  -- AND  id_app = v_idApp AND id_participante = v_idParticipante
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`mov_FIFO_varios`( IN    v_idApp 			BIGINT  
																 , IN    v_user 			VARCHAR(45)      -- Usuario que lanza el procedimiento
																 , INOUT v_retNum 			INT            -- "0" --> Creado; "1" --> Ya existe; "< 0" --> error; ">1" --> Errores de validación
																 , INOUT v_retTxt 			VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																 , IN    v_idParticipante 	BIGINT          -- 
																 , IN  	 v_puntos 			DECIMAL(11,2)   -- 
																)
BEGIN
/*
A esta función solo la puede llamar mov_FIFO_Anula porque es simplemente para aligerar la función origen
*/
DECLARE nExiste			int;
DECLARE dFecha			datetime;
DECLARE nSaldo 			DECIMAL(11,2);
DECLARE nPuntos			DECIMAL(11,2);
DECLARE nPuntosPendMov	DECIMAL(11,2);
DECLARE nPuntosPend		DECIMAL(11,2);
DECLARE nAnulado		DECIMAL(11,2);
DECLARE nCaducado		DECIMAL(11,2);
DECLARE nUtilizado		DECIMAL(11,2);
DECLARE cTipo			char(1);
DECLARE nidMov			BIGINT;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio mov_FIFO_varios';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de CURSORES
-- -----------------------------------------------------------------------------------------------------
DECLARE bFinCursor INT DEFAULT FALSE;

DECLARE cur1 CURSOR FOR 
	SELECT mov_movimientos.id, puntos - (anulado + caducado + utilizado) nPuntosPendMov
	  FROM mov_movimientos 
	 INNER JOIN mov_conceptos on mov_movimientos.id_concepto = mov_conceptos.id
	 where id_participante = v_idParticipante
       and mov_conceptos.tipo = 'B'     
       and (puntos - (anulado + caducado + utilizado)) > 0 -- Todavía quedan puntos pendientes de anular
	order by mov_movimientos.id asc
       FOR UPDATE;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET bFinCursor = TRUE;

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		SET v_retNum = 2;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'Consulta movimientos pendientes FIFO';
	SELECT sum(puntos),  sum(anulado),  sum(caducado),  sum(utilizado)
	  into 	  nPuntos, 	    nAnulado,      nCaducado,      nUtilizado
	  FROM mov_movimientos 
	 INNER JOIN mov_conceptos on mov_movimientos.id_concepto = mov_conceptos.id
	 where id_participante = v_idParticipante
       and mov_conceptos.tipo = 'B';
       
	IF row_count() != 1 then
		set v_retTxt = concat('No existen movimientos para hacer FIFO para el participante ', v_idParticipante);
		SIGNAL ex_controladas;
	end if;
	IF nPuntos < v_puntos THEN
		set v_retTxt = concat('No se puede realizar FIFO por ', v_puntos, ' porque el movimiento tiene ', nPuntos, ' Puntos');
		SIGNAL ex_controladas;
	end if;
	IF nPuntos < (nAnulado + nCaducado + nUtilizado + v_Puntos) THEN
		set v_retTxt = concat('No se puede realizar FIFO por ', v_puntos, ' porque el movimiento tiene ', nPuntos, ' Puntos y la suma de anulaciones, caducidades y canjes es ', (nAnulado + nCaducado + nUtilizado));
		SIGNAL ex_controladas;
	END IF;

    SET nPuntosPend =  v_puntos; -- Los puntos pendientes de anular al inicio son los que nos envían
    -- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    SET cDonde = 'update para FIFO ID. Abrimos curso';
    OPEN cur1;
	bucle:LOOP 
		IF nPuntosPend <= 0 Then
			LEAVE bucle;
        END IF;
		SET bFinCursor = false
		  , cDonde 	   = 'leemos cursor';
		FETCH cur1    into nidMov, nPuntosPendMov;
        IF bFinCursor THEN
			LEAVE bucle;
        END IF;
        
		IF nPuntosPendMov <= nPuntosPend THEN  -- Tenemos puntos de sobrar, por lo que anulamos toda la operación
			SET nPuntos = nPuntosPendMov;
		ELSE  -- Tenemos mas puntos en la operacion que pendientes de FIFO, solo hay que marcar anulados con los pendientes generales, el resto ya se anularan con otra operación o caducaran
			SET nPuntos = nPuntosPend;
		END IF;
		SET nPuntosPend = nPuntosPend - nPuntosPendMov
           ,cDonde 		= 'Actualizamos mov_movimientos';
           
		UPDATE mov_movimientos 
		   SET anulado		= anulado + nPuntos
			 , modified_by	= v_user
		 WHERE id			= nidMov;
	END LOOP;
    CLOSE cur1;
       
END;

CREATE DEFINER=`madre`@`localhost` PROCEDURE `madre`.`sem_crea_centro_y_contenido`( IN v_idApp 					BIGINT  
														, IN v_user 					VARCHAR(45)    -- Usuario que lanza el procedimiento
														, INOUT v_retNum 				INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														, INOUT v_retTxt 				VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
														, IN  v_id_idioma 				bigint
														, IN  v_id_dispositivo			bigint
														, IN  v_fecha 					VARCHAR(19)    -- '%Y-%m-%d %H:%i:%s' Fecha en la que queremos que todo esté activo
                                                        
														-- •	fijos:
														, IN  v_entorno					VARCHAR(4)	-- "DEV" o "PROD". si no es PROD siempre lo toma como DEV

														-- •	Centro:
														, IN  v_ctr_id					BIGINT
														, IN  v_ctr_nombre				VARCHAR(100)
														, IN  v_ctr_provincia			INT
														, IN  v_ctr_contacto			VARCHAR(100)
														, IN  v_ctr_teléfono			VARCHAR(15)
														, IN  v_ctr_email				VARCHAR(100)
														, IN  v_ctr_id_empresa			BIGINT
														-- •	Contenidos de centro:
														, IN  v_ctr_cnt_nombre			VARCHAR(100)
														, IN  v_ctr_cnt_imagen			VARCHAR(200)
														, IN  v_ctr_cnt_intro			VARCHAR(4000)
														, IN  v_ctr_cnt_desc			VARCHAR(4000)
														, IN  v_ctr_cnt_horario			VARCHAR(100)
														, IN  v_ctr_cnt_contact_voucher	VARCHAR(100)
														, IN  v_ctr_cnt_dir_voucher		VARCHAR(100)
														-- •	Semillas (Experiencias):
														, IN  v_sem_nombre				VARCHAR(100)
														, IN  v_sem_categorias			JSON		   -- tipo '["7", "9", "10"]'
														-- •	Contenidos de Semillas:
														, IN  v_sem_cnt_nombre			VARCHAR(4000)
														, IN  v_sem_cnt_imagen			VARCHAR(4000)
														, IN  v_sem_cnt_intro			VARCHAR(4000)
														, IN  v_sem_cnt_desc 			VARCHAR(4000)
														, IN  v_sem_cnt_subtitulo		VARCHAR(4000)
														, IN  v_sem_cnt_inf_extendida	VARCHAR(4000)
														, IN  v_sem_cnt_link			VARCHAR(4000)
														, IN  v_sem_cnt_como_conseguirlo	VARCHAR(4000)
														, IN  v_sem_cnt_como_canjearlo	VARCHAR(4000)
														, IN  v_sem_cnt_resumen			VARCHAR(4000)
														, IN  v_sem_cnt_resumen_desc	VARCHAR(4000)
														, IN  v_sem_cnt_CCGG			VARCHAR(4000)
														, IN  v_sem_cnt_imagen_voucher	VARCHAR(200)
														, IN  v_sem_cnt_desc_servicio	VARCHAR(4000)
														, IN  v_sem_cnt_como_funciona	VARCHAR(4000)
														, IN  v_pwd						VARCHAR(15)
                                                        )
BEGIN
/*
SELECT * FROM cnt_def_contenidos order by id desc;

SELECT * FROM hxxi_centros order by id desc;
SELECT * FROM hxxi_empresas order by id desc;
SELECT * FROM exp_centros order by id desc;

SELECT * FROM exp_experiencias order by id desc;
SELECT * FROM exp_experiencias_centros order by id desc;
SELECT * FROM exp_categorias order by id desc;
SELECT * FROM exp_categorias_experiencias order by id desc;

SELECT * FROM cnt_contenidos order by id desc;
SELECT * FROM cnt_posiciona order by id desc;
SELECT * FROM cnt_valores order by id desc;

*/
DECLARE nExiste			int;
DECLARE dFecha			datetime;
DECLARE nSaldo 			DECIMAL(11,2);
DECLARE cCncpt			CHAR(1);
DECLARE cFecCaducidad	Varchar(19);
DECLARE dCaducidad		DATE;

DECLARE nIdApp			BIGINT;
DECLARE nIdCentro		BIGINT;
DECLARE nIdContenido	BIGINT;
DECLARE cNombreApp		VARCHAR(100);
DECLARE nIdSemCnt		BIGINT;
DECLARE nIdSemPosiciona	BIGINT;
DECLARE nIdCtrCnt		BIGINT;
DECLARE nIdCtrPosiciona	BIGINT;
DECLARE nIdExperiencia	BIGINT;
DECLARE nIdCtrExp		BIGINT;

-- fijos:
DECLARE nIdDefCtrContenido			BIGINT;
DECLARE nIdDefSemContenido			BIGINT;
DECLARE nIdDefCampoContactoVoucher	INT;
DECLARE nIdDefCampoDirVoucher 		INT;

DECLARE nIdDefCampoCCGG		 		INT;
DECLARE nIdDefCampoDesServicio 		INT;
DECLARE nIdDefCampoComoFunciona		INT;
DECLARE nIdDefCampoImagVoucher 		INT;
DECLARE nIdDefCampoComoConseguir 	INT;
DECLARE nIdDefCampoSubtitulo 		INT;

-- Centro:
DECLARE cCtrNombre				VARCHAR(100)	DEFAULT v_ctr_nombre;
DECLARE nCtrProvincia			INT 			DEFAULT v_ctr_provincia;
DECLARE cCtrContacto			VARCHAR(100)	DEFAULT v_ctr_contacto;
DECLARE cCtrTeléfono			VARCHAR(15)		DEFAULT v_ctr_teléfono;
DECLARE cCtrEmail				VARCHAR(100)	DEFAULT v_ctr_email;
DECLARE nCtrIdEmpresa			BIGINT			DEFAULT v_ctr_id_empresa;

-- •	Contenidos de centro:
DECLARE cCtrCntNombre			VARCHAR(100)	DEFAULT v_ctr_cnt_nombre;
DECLARE cCtrCntImagen			VARCHAR(200)	DEFAULT v_ctr_cnt_imagen;
DECLARE cCtrCntIntro			VARCHAR(4000)	DEFAULT v_ctr_cnt_intro;
DECLARE cCtrCntDesc				VARCHAR(4000)	DEFAULT v_ctr_cnt_desc;
DECLARE cCtrCntHorario			VARCHAR(100)	DEFAULT v_ctr_cnt_horario;
DECLARE cCtrCntContactVoucher	VARCHAR(100)	DEFAULT v_ctr_cnt_contact_voucher;
DECLARE cCtrCntDirVoucher		VARCHAR(100)	DEFAULT v_ctr_cnt_dir_voucher;

-- Semillas (Experiencias):
DECLARE cSemNombre				VARCHAR(100)	DEFAULT v_sem_nombre;
DECLARE cSemCategorias			JSON	DEFAULT v_sem_categorias;		-- tipo '["1", "3", "4", "7"]'

-- Contenidos de Semillas:
DECLARE cSemCntNombre			VARCHAR(4000)	DEFAULT v_sem_cnt_nombre;
DECLARE cSemCntImagen			VARCHAR(4000)	DEFAULT v_sem_cnt_imagen;
DECLARE cSemCntIntro			VARCHAR(4000)	DEFAULT v_sem_cnt_intro;
DECLARE cSemCntDesc 			VARCHAR(4000)	DEFAULT v_sem_cnt_desc;
DECLARE cSemCntSubtitulo		VARCHAR(4000)	DEFAULT v_sem_cnt_subtitulo;
DECLARE cSemCntInfExtendida		VARCHAR(4000)	DEFAULT v_sem_cnt_inf_extendida;
DECLARE cSemCntLink				VARCHAR(4000)	DEFAULT v_sem_cnt_link;
DECLARE cSemCntComoConseguirlo	VARCHAR(4000)	DEFAULT v_sem_cnt_como_conseguirlo;
DECLARE cSemCntComoCanjearlo	VARCHAR(4000)	DEFAULT v_sem_cnt_como_canjearlo;
DECLARE cSemCntResumen			VARCHAR(4000)	DEFAULT v_sem_cnt_resumen;
DECLARE cSemCntResumenDesc		VARCHAR(4000)	DEFAULT v_sem_cnt_resumen_desc;
DECLARE cSemCntCCGG				VARCHAR(4000)	DEFAULT v_sem_cnt_CCGG;
DECLARE cSemCntImagenVoucher	VARCHAR(200)	DEFAULT v_sem_cnt_imagen_voucher;
DECLARE cSemCntDescServicio		VARCHAR(4000)	DEFAULT v_sem_cnt_desc_servicio;
DECLARE cSemCntComoFunciona		VARCHAR(4000)	DEFAULT v_sem_cnt_como_funciona;

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio sem_crea_centro_y_contenido';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		ROLLBACK;
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		ROLLBACK;
		SET v_retNum = -2;
	End;  
-- -----------------------------------------------------------------------------------------------------
-- VALIDACIONES
-- -----------------------------------------------------------------------------------------------------
	IF v_entorno = 'PROD' THEN
		SET nIdDefCampoContactoVoucher	= 2002; 
		SET nIdDefCampoDirVoucher		= 2003; 
		SET nIdDefCampoCCGG				= 2001;
		SET nIdDefCampoDesServicio		= 1999;
		SET nIdDefCampoComoFunciona		= 2000;
		SET nIdDefCampoImagVoucher		= 1997;
		SET nIdDefCampoComoConseguir	= 1998;
		SET nIdDefCampoSubtitulo		= 1996;
	ELSE
		SET nIdDefCampoContactoVoucher	= 1993; -- PROD:  2002; 
		SET nIdDefCampoDirVoucher		= 1992; -- PROD:  2003; 
		SET nIdDefCampoCCGG				= 1997; -- PROD:  2001;
		SET nIdDefCampoDesServicio		= 1995; -- PROD:  1999;
		SET nIdDefCampoComoFunciona		= 1996; -- PROD:  2000;
		SET nIdDefCampoImagVoucher		= 1994; -- PROD:  1997;
		SET nIdDefCampoComoConseguir	= 1991; -- PROD:  1998;
		SET nIdDefCampoSubtitulo		= 1990; -- PROD:  1996;
	END IF;
	IF v_fecha IS NULL THEN
		set dFecha = now();
	ELSE
		Select g_fecha_ok(v_fecha , '%Y-%m-%d %H:%i:%s', 'N') into v_retTxt;
		IF v_retTxt is not null THEN
			SIGNAL ex_controladas;
		END IF;
        select STR_TO_DATE(v_fecha, '%Y-%m-%d %H:%i:%s') into dfecha;
	END IF;
    
	SET cDonde = 'Validaciones1';
    SET nCtrIdEmpresa = v_ctr_id_empresa;
    
	SET cDonde = 'Validaciones2';
    SELECT nombre INTO cNombreApp FROM hxxi_aplicaciones where id = v_idApp;
	SET nIdApp= 61; -- Si no cambio el v_idApp por 61 (que es el de Madre imaginales) luego no funciona el voucher
	
	select id into nIdDefCtrContenido from cnt_def_contenidos where origen = "SEMILLAS" and clave = "Centros";
	select id into nIdDefSemContenido from cnt_def_contenidos where origen = "SEMILLAS" and clave = "Semillas";
	
-- -----------------------------------------------------------------------------------------------------
-- PROCESO
-- -----------------------------------------------------------------------------------------------------
	-- -----------------------------------------------------------------------------------------------------
	-- Insertamos Contenidos de Centros. 7 contenidos de los siguiente campos:
    -- 		campo	   grupo	orden	          nombre 			  promp 			Ejemplo de valor
    -- 	    -----	----------  -----	-----------------------	------------------	------------------------------------------------------------------------------	
	--    - 1928	1. General	1		nombre					Nombre				La BioDiversa
	--    - 1840	1. General	2		imagen					imagen				TUQVUW6a0G048bbM2GJxRxjjVUgyviZUX9ZSJxAe.png
	--    - 1841	1. General	3		intro					Intro				Oleoturismo<br />
 	--    - 1842	1. General	4		descripcion				Descripción			Jaén
 	--    - 1852	1. General	5		descripcion_extendida	Descripción	Ext		Nulo
	--    - 1875	1. General	6		horario					Horario				Lunes a viernes a partir de las 16:00 y fines de semana de 10:00 a 14:30 y 16:00 a 20:00
    -- 	PROD v_id_def_campo_contacto_voucher  y  v_id_def_campo_dir_voucher
	--    - 2002	2. Voucher	7		contacto_voucher		Contacto Voucher	Teléfono: 34 623 060 213<br />
 	--    - 2003	2. Voucher	8		dir_voucher				Dirección Voucher	Calle Fernando III, 1, Arjona (23760) Jaén
    -- 	DESA
    -- 	  - 1993	32	4	8	2. Voucher	contacto_voucher	Contacto Voucher	"{}"		2024-03-21 13:33:17	2024-03-25 17:15:22	
    -- 	  - 1992	32	4	13	2. Voucher	dir_voucher			Dirección Voucher	"{}"		2024-03-21 13:32:14	2024-04-10 12:49:53	
	-- -----------------------------------------------------------------------------------------------------
	
	SET cDonde = concat('cnt_contenidos1',nIdApp, nIdDefCtrContenido, CONCAT("Centro ", cCtrCntNombre," | ", cNombreApp),      v_user);
	INSERT INTO cnt_contenidos ( id_app,   id_def_contenido,                                        descripcion, modified_by)
						VALUES ( nIdApp, nIdDefCtrContenido, CONCAT("Centro ", cCtrCntNombre," | ", cNombreApp),      v_user);
	SET nIdCtrCnt = LAST_INSERT_ID();
    
	SET cDonde = 'cnt_posiciona1';
	INSERT INTO cnt_posiciona (id_cnt_contenidos,  desde, 						descripcion, modified_by)
					   VALUES (		   nIdCtrCnt, dfecha, "Cualquier dispositivo e idioma.",      v_user);
	SET nIdCtrPosiciona = LAST_INSERT_ID();

	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,				   valor1, modified_by)
					 VALUES (nIdCtrPosiciona, nIdDefCtrContenido,         1928, 		cCtrCntNombre,      v_user);		-- nombre
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,				   valor1, modified_by)
					 VALUES (nIdCtrPosiciona, nIdDefCtrContenido,         1840, 		cCtrCntImagen,      v_user);		-- imagen
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,				   valor1, modified_by)
					 VALUES (nIdCtrPosiciona, nIdDefCtrContenido,         1841, 		 cCtrCntIntro,      v_user);		-- intro
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,				   valor1, modified_by)
					 VALUES (nIdCtrPosiciona, nIdDefCtrContenido,         1842, 		  cCtrCntDesc,      v_user);		-- descripcion
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,				   valor1, modified_by)
					 VALUES (nIdCtrPosiciona, nIdDefCtrContenido,         1852, 		  		 null,      v_user);		-- descripcion Extendida
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,				   valor1, modified_by)
					 VALUES (nIdCtrPosiciona, nIdDefCtrContenido,         1875, 	   cCtrCntHorario,      v_user);		-- horario
	SET cDonde = 'cnt_valores1';
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido,               id_def_campo,          	     valor1, modified_by)
					 VALUES (nIdCtrPosiciona, nIdDefCtrContenido, nIdDefCampoContactoVoucher, cCtrCntContactVoucher,      v_user);		-- contacto_voucher
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido,               id_def_campo,				 valor1, modified_by)
					 VALUES (nIdCtrPosiciona, nIdDefCtrContenido,	   nIdDefCampoDirVoucher,	  cCtrCntDirVoucher,      v_user);		-- dir_voucher
					 
	-- -----------------------------------------------------------------------------------------------------
	-- Insertamos Contenidos de Semillas. 16 contenidos de los siguiente campos:
    -- 		campo	   grupo	orden	          nombre 			  promp 			Ejemplo de valor
    -- 	    -----	----------  -----	-----------------------	------------------	------------------------------------------------------------------------------	
	--    - 1927	1. General	1		nombre					nombre				La BioDiversa
	--    - 1835	1. General	2		imagen					Imagen				14wSwxG0ebyEbi29Y3wO3bVqWzyDSqRggjrv5jiw.png
	--    - 1836	1. General	3		intro					Intro				Visitas guiadas al olivar y catas con maridaje
	--    - 1837	1. General	4		descripcion				Descripcion			Visitas guiadas al olivar y catas con maridaje
	--    - 1854	1. General	6		info_extendida			Inf_extendida		Conoce nuestro AOVE, pura inspiración culinaria.<br />, ............
 	--    - 1838	1. General	7		link					Link				https://labiodiversa.com/
	--    - 1839	1. General	9		como_canjear			Cómo canjearlo		Sigue las intrucciones descritas en el voucher que ............
	--    - 1855	1. General	10		resumen_titulo			Resumen-título		LA BIODIVERSA
    -- 	  - 1856	1. General	11		resumen_descripcion		Resumen-Descripción	Resumen - Descripción [resumen_descripcion] ...............
	--    - 1876	1. General	12		condiciones				Condiciones			Para realizar la reserva es necesario ............
    -- 	PROD: parametros de entrada fijos
	--    - 2001	2. Voucher	16		ccgg_voucher			CCGG				Para realizar la reserva es necesario contactar con el e ............
	--    - 1999	2. Voucher	14		desc_servicio_voucher	Desc. Servicio		Visitas guiadas al olivar y catas con maridaje<br  ............
	--    - 2000	2. Voucher	15		como_funciona_voucher	Como Funciona		<ul style="list-style: none;  padding: 0;"> ............
	--    - 1997	2. Voucher	13		imagen_voucher			Imagen Voucher		mqaOzaG8RTgIZAHTFwZUbHT3kRUX8c13U52TzJNQ.png
	--    - 1998	1. General	8		como_conseguir			Cómoconseguirlo		Una vez que hayas indicado tus datos y los confirmes, ............
	--    - 1996	1. General	5		subtitle				Subtítulo			Promoviendo la Biodiversidad
    -- 	DESA: parametros de entrada fijos    
	--    - 1997	30	4	16	2. Voucher	ccgg_voucher			CCGG	"{}"		2024-03-25 17:13:41	2024-03-25 17:13:41	
	--    - 1996	30	4	15	2. Voucher	como_funciona_voucher	Como Funciona	"{}"		2024-03-25 17:12:55	2024-03-25 17:12:55	
	--    - 1995	30	4	14	2. Voucher	desc_servicio_voucher	Descripción Servicio	"{}"		2024-03-25 17:12:18	2024-03-25 17:12:18	
	--    - 1994	30	10	7	2. Voucher	imagen_voucher			Imagen Voucher	"{}"		2024-03-25 17:11:29	2024-03-25 17:16:35	
	--    - 1991	30	4	8	1. General	como_conseguir			Cómo conseguirlo	"{}"		2024-03-12 15:45:07	2024-03-12 15:45:20	
	--    - 1990	30	4	5	1. General	subtitle				Subtítulo	"{}"		2024-03-12 15:43:38	2024-07-08 17:19:16	

    
 	-- -----------------------------------------------------------------------------------------------------
	SET cDonde = 'cnt_contenidos2';
	INSERT INTO cnt_contenidos ( id_app,   id_def_contenido,                                             descripcion, modified_by)
						VALUES ( nIdApp, nIdDefSemContenido, CONCAT("Experiencia ", cCtrCntNombre," | ", cNombreApp),      v_user);
	SET nIdSemCnt = LAST_INSERT_ID();
    
	SET cDonde = 'cnt_posiciona2';
	INSERT INTO cnt_posiciona (id_cnt_contenidos,  desde, 						descripcion, modified_by)
					   VALUES (		   nIdSemCnt, dfecha, "Cualquier dispositivo e idioma.",      v_user);
	SET nIdSemPosiciona = LAST_INSERT_ID();

	SET cDonde = 'cnt_valores2';
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,        			valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido,         1927, 		 cSemCntNombre,      v_user);		-- nombre
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,        			valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido,         1835, 		 cSemCntImagen,      v_user);		-- imagen
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,       			valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido,         1836,   		  cSemCntIntro,      v_user);		-- intro
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,     			valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido,         1837, 		   cSemCntDesc,      v_user);		-- descripcion
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido,         id_def_campo,    		  valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido, nIdDefCampoSubtitulo, cSemCntSubtitulo,      v_user);		-- subtitle
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,                 valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido,         1854,	   cSemCntInfExtendida,      v_user);		-- info_extendida
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,      			valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido,         1838, 		   cSemCntLink,      v_user);		-- link
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido,             id_def_campo,                 valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido, nIdDefCampoComoConseguir, cSemCntComoConseguirlo,      v_user);		-- como_conseguir
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,                 valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido,         1839,   cSemCntComoCanjearlo,      v_user);		-- como_canjear
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,        		    valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido,         1855, 	cSemCntResumenDesc,      v_user);		-- resumen_titulo
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,        		    valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido,         1856, 	    cSemCntResumen,      v_user);		-- resumen_descripcion
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido,    id_def_campo, 	    valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido, nIdDefCampoCCGG, cSemCntCCGG,      v_user);		-- condiciones
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido,           id_def_campo,               valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido, nIdDefCampoImagVoucher, cSemCntImagenVoucher,      v_user);		-- imagen_voucher
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido,           id_def_campo,              valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido, nIdDefCampoDesServicio, cSemCntDescServicio,      v_user);		-- desc_servicio_voucher
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido,            id_def_campo,              valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido, nIdDefCampoComoFunciona, cSemCntComoFunciona,      v_user);		-- como_funciona_voucher
	INSERT INTO cnt_valores (   id_posiciona,   id_def_contenido, id_def_campo,                 valor1, modified_by)
					 VALUES (nIdSemPosiciona, nIdDefSemContenido,         2001,            cSemCntCCGG,      v_user);		-- ccgg_voucher

	-- -----------------------------------------------------------------------------------------------------
	-- Insertamos centros y empresas
	-- -----------------------------------------------------------------------------------------------------
    -- primero creamos la empresa porque luego habrá que modificarla con su centro principal
    IF v_ctr_id_empresa = 0 then
		SET cDonde = 'hxxi_empresas1';
		INSERT INTO hxxi_empresas (nombre) 	VALUES (cCtrNombre);
		SET nCtrIdEmpresa = LAST_INSERT_ID();
    END IF;
	SET cDonde = 'hxxi_centros';
	INSERT INTO hxxi_centros  (id_empresa, 		  nombre, estado, fec_alta,     contacto,     telefono,     email, modified_by)
						VALUES(nCtrIdEmpresa, cCtrNombre,   "AC",   dfecha, cCtrContacto, cCtrTeléfono, cCtrEmail, v_user);
	SET nIdCentro = LAST_INSERT_ID();

    IF v_ctr_id_empresa = 0 then
		SET cDonde = 'hxxi_empresas2';
		UPDATE hxxi_empresas SET id_centro_principal = nIdCentro WHERE (id = nCtrIdEmpresa);
    END IF;
    
	SET cDonde = 'exp_centros2';
    INSERT INTO exp_centros (id_centro, id_contenido,  id_provincia, estado,  desde, modified_by)
					 VALUES (nIdCentro,    nIdCtrCnt, nCtrProvincia,    '1', dFecha,      v_user);
	SET nIdCtrExp = LAST_INSERT_ID();

	-- -----------------------------------------------------------------------------------------------------
	-- Insertamos los datos relacionados con la Semilla/Experiencia
	-- -----------------------------------------------------------------------------------------------------
	SET cDonde = 'exp_experiencias';
	INSERT INTO exp_experiencias (id_contenido,     nombre, estado,  desde, modified_by)
						  VALUES (   nIdSemCnt, cSemNombre,    '1', dFecha,      v_user);
	SET nIdExperiencia = LAST_INSERT_ID();

	SET cDonde = 'exp_experiencias_centros';
	INSERT INTO exp_experiencias_centros (id_experiencia, id_centro, modified_by)
								  VALUES (nIdExperiencia, nIdCtrExp,      v_user);

    BEGIN
	  DECLARE i INT DEFAULT 0;
	  DECLARE total INT;
	  DECLARE valor VARCHAR(50);

	  SET total = JSON_LENGTH(cSemCategorias);

	  WHILE i < total DO
		SET valor = JSON_UNQUOTE(JSON_EXTRACT(cSemCategorias, CONCAT('$[', i, ']')));
		-- SELECT CONCAT('Elemento procesado: ', valor);
		SET cDonde = concat('exp_categorias_experiencias ', nIdExperiencia, " - ", valor);
		INSERT INTO exp_categorias_experiencias (id_experiencia, id_categoria, modified_by)
										 VALUES (nIdExperiencia, 		valor,      v_user);
		SET i = i + 1;
	  END WHILE;
	END;
	SET v_retNum = 0;
	SET v_retTxt = "OK";

END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_cdx_canje`( IN v_idApp 		BIGINT  
																, IN v_user 		VARCHAR(45)         -- Usuario que lanza el procedimiento
																, INOUT v_retNum 	INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																, INOUT v_retTxt 	VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                                
																, IN  v_precodigo		 VARCHAR(25) 
																, INOUT v_id_participante BIGINT 
																, IN  v_id_frontal		 BIGINT 
																, IN  v_id_campaign		 BIGINT 
																, IN  v_id_prod			 BIGINT 
																, IN  v_id_cat			 BIGINT 
																
																, IN  v_unidades	 	 INT 
																, IN  v_puntos		 	 INT 
																, IN  v_fec_canje		 VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																, IN  v_links_vouchers	 VARCHAR(4000)
																
																, IN  v_json_datos		 VARCHAR(4000)     -- Datos de campos variablesvariable
																, IN  v_json_fichero	 VARCHAR(4000)     -- Lista de ficheros asociados al canje

																, IN  v_fiscales		 VARCHAR(1)   	-- S o N, uno de los dos obligatorios y si es "S" debe llevar los datos fiscaless
																, IN  v_fiscal_nombre	 VARCHAR(200)   -- o razon social
																, IN  v_fiscal_apell	 VARCHAR(200)	
																, IN  v_fiscal_dni		 VARCHAR(19)     
																, IN  v_fiscal_telf		 VARCHAR(19)     
																, INOUT v_idFiscalDir	 BIGINT       -- si viene este campo no se tiene en cuenta la dirección
																, IN  v_fiscal_dir1		 VARCHAR(200)     
																, IN  v_fiscal_id_prov	 BIGINT     
																, IN  v_fiscal_CP		 VARCHAR(10)     
																, IN  v_fiscal_localidad VARCHAR(75)     
																
																, OUT v_id   		BIGINT          -- ID de la operación creada
																)
BEGIN
-- -----------------------------------------------------------------------------------------------------
-- Realiza el canje que ha pedido el cliente con su precodigo
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio w_cdx_canje';
DECLARE ex_controladas	CONDITION FOR SQLSTATE '45000';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------

    SET v_retNum = null;
    SET v_retTxt = 'Todo Ok';

    START TRANSACTION;
		Call cdx_canje( v_idApp     , v_user 			, v_retNum 			, v_retTxt
					  , v_precodigo , v_id_participante	, v_id_frontal  	, v_id_campaign		, v_id_prod			, v_id_cat
					  , v_unidades  , v_puntos			, v_fec_canje		, v_links_vouchers	
                      , v_json_datos, v_json_fichero	
					  , v_fiscales  , v_fiscal_nombre	, v_fiscal_apell	, v_fiscal_dni		, v_fiscal_telf	
                      ,v_idFiscalDir, v_fiscal_dir1		, v_fiscal_id_prov	, v_fiscal_CP		, v_fiscal_localidad, v_id);
        
        IF v_retNum >= 0 Then
			COMMIT;
		END IF;    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_cdx_valida_precodigo`( IN v_idApp 				BIGINT  
																	  , IN v_user 				VARCHAR(45)         -- Usuario que lanza el procedimiento
																	  , INOUT v_retNum 			INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																	  , INOUT v_retTxt 			VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																	  , IN  v_precodigo			VARCHAR(30)
																	  , IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																	  , IN  v_url				VARCHAR(400) 	-- LLeva URL o ....
																	  , INOUT v_idFrontal		BIGINT			-- ... lleva IdFrontal
																	  , OUT v_idCatalogo		BIGINT
																	  , OUT v_idCampaign		BIGINT
                                                                      , OUT v_idCanje			BIGINT
																	  , OUT v_idParticipante	BIGINT
                                                                      , OUT v_idPrecodigo		BIGINT
																	  )
BEGIN
DECLARE cModulo		VARCHAR(5) default 'CDX';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_cdx_valida_precodigo';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

DECLARE exit HANDLER FOR SQLEXCEPTION, ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

	IF v_user is null or v_idApp is null THEN 
        set v_retTxt = 'Debe indicar un Usuario responsable creador del movimiento o un ID de aplicación';
		SIGNAL ex_controladas;
	END IF;

    START TRANSACTION;
		Call cdx_valida_precodigo(v_idApp, v_user, v_retNum, v_retTxt, cModulo, v_precodigo, v_fecha, v_url, v_idFrontal, v_idCatalogo, v_idCampaign, v_idCanje, v_idParticipante, v_idPrecodigo);
    commit;   
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_cdx_valida_url`( IN v_idApp 		BIGINT  
																, IN v_user 		VARCHAR(45)         -- Usuario que lanza el procedimiento
																, INOUT v_retNum 	INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																, INOUT v_retTxt 	VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																, IN  v_url			VARCHAR(400)   -- 
																, IN  v_fecha 		VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																, OUT v_Frontal		BIGINT
																, OUT v_Catalogo	BIGINT
																)
BEGIN
DECLARE cModulo		VARCHAR(5) default 'CDX';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_cdx_valida_url';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

DECLARE exit HANDLER FOR SQLEXCEPTION, ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

	IF v_user is null or v_idApp is null THEN 
        set v_retTxt = 'Debe indicar un Usuario responsable creador del movimiento o un ID de aplicación';
		SIGNAL ex_controladas;
	END IF;

    START TRANSACTION;
		Call cdx_valida_url(v_idApp, v_user, v_retNum, v_retTxt, v_url, cModulo, v_fecha, v_Frontal, v_Catalogo);
    commit;   
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_cnj_anula`( IN v_idApp BIGINT  
														, IN v_user VARCHAR(45)         -- Usuario que lanza el procedimiento
														, INOUT v_retNum INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														, INOUT v_retTxt VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                     
														, IN  v_id bigint
														, IN  v_unidades int              -- por seguridad debe coincidir con lo que tenga v_id
														, IN  v_puntos decimal(8,2)       -- por seguridad debe coincidir con lo que tenga v_id

														, OUT  v_estado varchar(1)
														, OUT  v_id_mov_anula bigint
														, OUT v_saldo DECIMAL(11,2)   -- 
                                                        )
BEGIN
-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_cnj_anula';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

DECLARE exit HANDLER FOR SQLEXCEPTION, ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

	IF v_user is null or v_idApp is null THEN 
        set v_retTxt = 'Debe indicar un Usuario responsable creador del movimiento o un ID de aplicación';
		SIGNAL ex_controladas;
	END IF;


    START TRANSACTION;
		SET v_id_mov_anula = DATE_FORMAT(now(), "%s%i%H%d");
		SET v_saldo        = 1010;
		SET v_estado       = 5; -- anulado
		-- Call cnj_anula -- (v_idApp, v_user, v_retNum, v_retTxt, v_idDef, v_producto, v_fecha);
    commit;   
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_cnj_crea`( IN v_idApp BIGINT  
														, IN v_user VARCHAR(45)         -- Usuario que lanza el procedimiento
														, INOUT v_retNum INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														, INOUT v_retTxt VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                     
														, IN  v_id_participante bigint
														, IN  v_id_cat bigint
														, IN  v_id_producto bigint
														, IN  v_links_vouchers varchar(4000)     -- dato para poder acceder a la descarga del link de génesis. Formato: [{\"link\":\"https:\\/\\/gentestcore.helloyalty.cloud\\/download-voucher\\/2d8da74857d183ea59a5\",\"inicio_validez_cupon\":\"2022-05-12T18:34:16+02:00\",\"fin_validez_cupon\":null,\"valor\":\"10.00\"}]

														, IN  v_unidades int
														, IN  v_puntos decimal(8,2)
														, IN  v_fec_canje VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'

														, IN  v_nombre varchar(50)
														, IN  v_email varchar(255)
														, IN  v_telf varchar(15)
														, IN  v_fiscal_nombre varchar(50)
														, IN  v_fiscal_apellidos varchar(50)
														, IN  v_fiscal_dni varchar(20)
														, IN  v_fiscal_telefono varchar(20)
-- lo hemos declardo como variable						, IN  v_fiscal_dir_dir varchar(255)
														, IN  v_Dir			 	varchar(255)
														, IN  v_cp varchar(25)
														, IN  v_id_provincia bigint
														, IN  v_localidad varchar(255)

														, INOUT  v_estado varchar(1)
														, OUT  v_id_cnj bigint
														, OUT  v_id_mov_canje bigint
														, OUT v_saldo DECIMAL(11,2)   -- 
                                                        )
BEGIN
Declare v_fiscal_dir_dir varchar(255);

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_cnj_crea';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

    START TRANSACTION;
		SELECT IFNULL(v_estado,1) into v_estado;
		Call cnj_crea( v_idApp      , v_user            , v_retNum         , v_retTxt , v_id_participante , v_id_cat        , v_id_producto   , v_links_vouchers 
					 , v_unidades   , v_puntos          , v_fec_canje      , v_nombre , v_email           , v_telf          , v_fiscal_nombre , v_fiscal_apellidos
					 , v_fiscal_dni , v_fiscal_telefono , v_fiscal_dir_dir , v_dir    , v_cp              , v_id_provincia  , v_localidad     , v_estado 
					 , v_id_cnj     , v_id_mov_canje    , v_saldo);
		IF v_retNum = 0 Then
			commit;   
		else
			rollback;
		END IF;    
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_cnj_crea_comprueba`( IN v_idApp BIGINT  
														, IN v_user VARCHAR(45)         -- Usuario que lanza el procedimiento
														, INOUT v_retNum INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														, INOUT v_retTxt VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                     
														, IN  v_id_participante bigint
														, IN  v_id_cat bigint
														, IN  v_id_producto bigint
														, IN  v_links_vouchers varchar(4000)     -- dato para poder acceder a la descarga del link de génesis. Formato: [{\"link\":\"https:\\/\\/gentestcore.helloyalty.cloud\\/download-voucher\\/2d8da74857d183ea59a5\",\"inicio_validez_cupon\":\"2022-05-12T18:34:16+02:00\",\"fin_validez_cupon\":null,\"valor\":\"10.00\"}]

														, IN  v_unidades int
														, IN  v_puntos decimal(8,2)
														, IN  v_fec_canje VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'

														, IN  v_nombre varchar(50)
														, IN  v_email varchar(255)
														, IN  v_telf varchar(15)
														, IN  v_fiscal_nombre varchar(50)
														, IN  v_fiscal_apellidos varchar(50)
														, IN  v_fiscal_dni varchar(20)
														, IN  v_fiscal_telefono varchar(20)
														, IN  v_Dir			 	varchar(255)
														, IN  v_cp varchar(25)
														, IN  v_id_provincia bigint
														, IN  v_localidad varchar(255)

														, INOUT  v_estado varchar(1)
                                                        )
BEGIN
Declare v_fiscal_dir_dir varchar(255);

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'w_cnj_crea_comprueba';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

    START TRANSACTION;
		SELECT IFNULL(v_estado,1) into v_estado;
		Call cnj_crea_comprueba ( v_idApp      , v_user            , v_retNum         , v_retTxt , v_id_participante , v_id_cat        , v_id_producto   , v_links_vouchers 
								, v_unidades   , v_puntos          , v_fec_canje      , v_nombre , v_email           , v_telf          , v_fiscal_nombre , v_fiscal_apellidos
								, v_fiscal_dni , v_fiscal_telefono , v_fiscal_dir_dir , v_dir    , v_cp              , v_id_provincia  , v_localidad     , v_estado);
		IF v_retNum = 0 Then
			commit;   
		else
			rollback;
		END IF;    
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_dir_crea`( IN v_idApp 			BIGINT  
														, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
														, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum != 0)
                                                     
														, IN  v_idParticipante 	bigint
														, IN  v_tipo			char(1)			-- 1 --> personal; 2 --> canje; 3 --> Fiscal (no se puede modificar)
														, IN  v_dir1	 		varchar(255)
														, IN  v_dir2			varchar(255)
														, IN  v_numero			varchar(15)
														, IN  v_complemento		varchar(15)
														, IN  v_portal_bloque	varchar(15)
														, IN  v_escalera		varchar(15)
														, IN  v_planta			varchar(15)
														, IN  v_puerta			varchar(15)
														, IN  v_CP				varchar(25)
                                                        , IN  v_codPais			varchar(25)
                                                        , IN  v_codComunidad	varchar(25)
														, IN  v_codProv			varchar(25)
														, IN  v_localidad 		varchar(255)

														, OUT  v_idDir 			bigint
                                                        )
BEGIN

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio w_dir_crea';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

    START TRANSACTION;
		Call dir_crea(v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, v_tipo, v_dir1, v_dir2
					 , v_numero, v_complemento, v_portal_bloque, v_escalera, v_planta, v_puerta, v_CP, v_codPais, v_codComunidad, v_codProv, v_localidad, v_idDir);
                     
		IF v_retNum = 0 Then
			commit;   
		else
			rollback;
		END IF;    
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_dir_modifica`( IN v_idApp 		BIGINT  
														, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
														, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum != 0)

														, IN  v_id				bigint
														, IN  v_idParticipante 	bigint
														, IN  v_tipo			char(1)			-- 1 --> personal; 2 --> canje; 3 --> Fiscal (no se puede modificar)
														, IN  v_dir1	 		varchar(255)
														, IN  v_dir2			varchar(255)
														, IN  v_numero			varchar(15)
														, IN  v_complemento		varchar(15)
														, IN  v_portal_bloque	varchar(15)
														, IN  v_escalera		varchar(15)
														, IN  v_planta			varchar(15)
														, IN  v_puerta			varchar(15)
														, IN  v_CP				varchar(25)
                                                        , IN  v_codPais			varchar(25)
                                                        , IN  v_codComunidad	varchar(25)
														, IN  v_codProv			varchar(25)
														, IN  v_localidad 		varchar(255)
                                                        )
BEGIN

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio w_dir_modifica';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

    START TRANSACTION;
		Call dir_modifica( v_idApp, v_user, v_retNum, v_retTxt, v_id, v_idParticipante, v_tipo, v_dir1, v_dir2
						 , v_numero, v_complemento, v_portal_bloque, v_escalera, v_planta, v_puerta, v_CP, v_codPais, v_codComunidad, v_codProv, v_localidad);

		IF v_retNum = 0 Then
			commit;   
		else
			rollback;
		END IF;    
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_exp_canje`( IN v_idApp 		BIGINT  
																, IN v_user 		VARCHAR(45)         -- Usuario que lanza el procedimiento
																, INOUT v_retNum 	INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																, INOUT v_retTxt 	VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
                                                                
																, IN  v_precodigo		 VARCHAR(25) 
																, INOUT v_id_participante BIGINT 
																, IN  v_id_frontal		 BIGINT 
																, IN  v_id_campaign		 BIGINT 
																, IN  v_id_semilla		 BIGINT
                                                                , IN  v_id_centro		 BIGINT
																, IN  v_id_cat			 BIGINT
																, IN  v_fec_canje		 VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																, IN  v_links_vouchers	 VARCHAR(4000)
																
																, IN  v_json_datos		 VARCHAR(4000)     -- Datos de campos variablesvariable
																, IN  v_json_fichero	 VARCHAR(4000)     -- Lista de ficheros asociados al canje
																
																, OUT v_id   		BIGINT          -- ID de la operación creada
																)
BEGIN
-- -----------------------------------------------------------------------------------------------------
-- Realiza el canje que ha pedido el cliente con su precodigo
-- -----------------------------------------------------------------------------------------------------
DECLARE xUnidades	INT		DEFAULT 1;
DECLARE xPuntos		INT		DEFAULT 0;

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio w_exp_canje';
DECLARE ex_controladas	CONDITION FOR SQLSTATE '45000';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------

    SET v_retNum = null;
    SET v_retTxt = 'Todo Ok';

    START TRANSACTION;
		Call exp_canje( v_idApp     , v_user 			, v_retNum 		, v_retTxt
					  , v_precodigo , v_id_participante	, v_id_frontal  , v_id_campaign		, v_id_semilla	, v_id_cat	, v_id_centro
					  , xUnidades   , xPuntos			, v_fec_canje	, v_links_vouchers	
                      , v_json_datos, v_json_fichero	, v_id);

        IF v_retNum >= 0 Then
			COMMIT;
		END IF;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_exp_valida_precodigo`( IN v_idApp 				BIGINT  
																	  , IN v_user 				VARCHAR(45)         -- Usuario que lanza el procedimiento
																	  , INOUT v_retNum 			INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado; 2 --> El precodigo ya ha sido canjeado
																	  , INOUT v_retTxt 			VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																	  , IN	  v_precodigo		VARCHAR(30)
																	  , IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																	  , IN  v_url				VARCHAR(400) 	-- LLeva URL o ....
																	  , INOUT v_idFrontal		BIGINT			-- ... lleva IdFrontal
																	  , OUT v_idCatalogo		BIGINT
																	  , OUT v_idCampaign		BIGINT
                                                                      , OUT v_idCanje			BIGINT
																	  , OUT v_idParticipante	BIGINT
                                                                      , OUT v_idPrecodigo		BIGINT
																	  )
BEGIN
DECLARE cModulo		VARCHAR(5) default 'XPR';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_exp_valida_precodigo';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

DECLARE exit HANDLER FOR SQLEXCEPTION, ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

	IF v_user is null or v_idApp is null THEN 
        set v_retTxt = 'Debe indicar un Usuario responsable creador del movimiento o un ID de aplicación';
		SIGNAL ex_controladas;
	END IF;

    START TRANSACTION;
		Call exp_valida_precodigo(v_idApp, v_user, v_retNum, v_retTxt, cModulo, v_precodigo, v_fecha, v_url, v_idFrontal, v_idCatalogo, v_idCampaign, v_idCanje, v_idParticipante, v_idPrecodigo);
    -- commit;   
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_exp_valida_url`( IN v_idApp 		BIGINT  
																, IN v_user 		VARCHAR(45)         -- Usuario que lanza el procedimiento
																, INOUT v_retNum 	INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																, INOUT v_retTxt 	VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																, IN  v_url			VARCHAR(400)   -- 
																, IN  v_fecha 		VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																, OUT v_Frontal		BIGINT
																, OUT v_Catalogo	BIGINT
																)
BEGIN
DECLARE cModulo		VARCHAR(5) default 'XPR';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_exp_valida_url';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

DECLARE exit HANDLER FOR SQLEXCEPTION, ex_controladas
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

	IF v_user is null or v_idApp is null THEN 
        set v_retTxt = 'Debe indicar un Usuario responsable creador del movimiento o un ID de aplicación';
		SIGNAL ex_controladas;
	END IF;

    START TRANSACTION;
		Call cdx_valida_url(v_idApp, v_user, v_retNum, v_retTxt, v_url, cModulo, v_fecha, v_Frontal, v_Catalogo);
    commit;   
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_hxxi_APIs_in`( IN    v_idApp 	BIGINT          -- (Valor nulo --> 0)   
															, IN    v_user 		VARCHAR(45)      -- Usuario que lanza el procedimiento
															, INOUT v_retNum 	INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															, INOUT v_retTxt 	VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0))
															, IN    v_metodo 	VARCHAR(100)     
															, IN    v_log 		VARCHAR(4000)   
                                                            , OUT	v_fecIni	VARCHAR(30)		-- '%Y-%m-%d %H:%i:%s.%f'
															)
BEGIN
/*
Esta función se ha de llamar como PRIMERA instrucción del servicio y no influye en la ejecución del mismo, si es Ok se continua y 
si es KO se continua pero se guarda el error en el sistema de LOG de PHP

c_fecIni es la fecha que se ha de enviar al procedimiento w_hxxi_APIs_out
*/

DECLARE cLog 		VARCHAR(4000);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio w_hxxi_APIs_in';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
		SET v_retNum = -1;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	SELECT NOW(6) into v_fecIni;

    SET cLog       = v_log;
	IF IFNULL(cLog, '_') = '_'  THEN 
		SET cLog = 'Vacio';
	END IF;
    SET cLog = substr(Concat(str_to_date(v_fecIni, '%Y-%m-%d %H:%i:%s.%f'), '. ', cLog), 1, 4000);
    
	IF ifnull(v_idApp, 0) = 0  THEN 
        set v_retTxt = 'Error de parámetros. Falta el IdApp';
		SIGNAL ex_controladas;
	END IF;
	IF ifnull(v_metodo, '_') = '_'  THEN 
        set v_retTxt = 'Error de parámetros. Falta el Método';
		SIGNAL ex_controladas;
	END IF;
	-- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    START TRANSACTION;
		insert into hxxi_APIs	(id_app,  metodo,   accion,  log, modified_by) 
						values	(v_idApp, v_metodo, 'I',    cLog, substr(v_user,45));
    commit;   
 	SET v_retNum = 0;
    SET v_retTxt = 'LOG entrada creado correctamente.';   
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_hxxi_APIs_out`( IN    v_idApp 	BIGINT          -- (Valor nulo --> 0)   
															 , IN    v_user 		VARCHAR(45)      -- Usuario que lanza el procedimiento
															 , INOUT v_retNum 	INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
															 , INOUT v_retTxt 	VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0))
                                                             , IN 	 v_fecIni	VARCHAR(30)		-- '%Y-%m-%d %H:%i:%s.%f'
															 , IN    v_metodo 	VARCHAR(100)     
															 , IN    v_log 		VARCHAR(4000)     
															 )
BEGIN
/*
Esta función se ha de llamar como ULTIMA instrucción del servicio y no influye en la ejecución del mismo, si es Ok se continua y 
si es KO se continua pero se guarda el error en el sistema de LOG de PHP

v_fecIni es la fecha que que se ha recogido en  w_hxxi_APIs_in
*/

DECLARE cLog 		VARCHAR(4000);
DECLARE dEntrada	TIMESTAMP(6);
DECLARE cDif		VARCHAR(100);

-- DECLARACIÓN variables de ERRORES
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio w_hxxi_APIs_out';
DECLARE ex_controladas CONDITION FOR SQLSTATE '45000';

-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;

		SET v_retNum = null;
		SET v_retTxt = null;
		ROLLBACK;
	   
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;
DECLARE exit HANDLER FOR ex_controladas
	Begin
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
		SET v_retNum = -1;
	End;    
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    -- Validaciones y asignaciones de parametros de entrada
    -- -----------------------------------------------------------------------------------------------------
	SELECT NOW(6) into dEntrada;
    SET cDif  = now(6) - STR_TO_DATE('2022-03-19 08:07:19.181991', '%Y-%m-%d %H:%i:%s.%f');
	IF ifnull(v_fecIni, '_') = '_'  THEN 
        set v_retTxt = 'Error de parámetros. Falta el v_fecIni';
		SIGNAL ex_controladas;
	END IF;

    SET cLog 	= substr(Concat(v_fecIni, ' - ', str_to_date(dEntrada, '%Y-%m-%d %H:%i:%s.%f'), ' (', cDif, '). ', IFNULL(v_log, 'Vacio')), 1, 4000);
    
	IF ifnull(v_idApp, 0) = 0  THEN 
        set v_retTxt = 'Error de parámetros. Falta el IdApp';
		SIGNAL ex_controladas;
	END IF;
	IF ifnull(v_metodo, '_') = '_'  THEN 
        set v_retTxt = 'Error de parámetros. Falta el Método';
		SIGNAL ex_controladas;
	END IF;
	-- -----------------------------------------------------------------------------------------------------
    -- PROCESO
    -- -----------------------------------------------------------------------------------------------------
    START TRANSACTION;
	insert into hxxi_APIs	(id_app,  metodo,   accion, log,   modified_by) 
					values	(v_idApp, v_metodo, 'O',    cLog, substr(v_user,45));
    commit;   
	SET v_retNum = 0;
    SET v_retTxt = 'LOG Salida creado correctamente.';
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_hxxi_crea_log`( IN v_idApp BIGINT  
                                                          , IN v_user VARCHAR(45)         -- Usuario que lanza el procedimiento
                                                          , INOUT v_retNum INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
                                                          , INOUT v_retTxt VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
														  , IN    v_tipo VARCHAR(1)       -- (Otro valor o nulo --> "E") 'A' --> Aviso;  'E' --> Error; 'I' --> Incidencia. 
														  , IN    v_accion CHAR(1)        -- (otro valor o nulo --> "2") 0 --> No ha roto el proceso ni la función en la que se ejecuta; 1 --> la función que se ejecuta, se ha quedado a medias en algún lugar; 2 --> se ha debido romper el proceso
														  , IN    v_RETURNED_SQLSTATE VARCHAR(4000)
														  , IN    v_MESSAGE_TEXT VARCHAR(4000)
														  , IN    v_MYSQL_ERRNO VARCHAR(4000)
														  , IN    v_Log VARCHAR(4000)     
														  )
BEGIN
-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_hxxi_crea_log';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

    START TRANSACTION;
		Call hxxi_crea_log(v_idApp, v_tipo, v_accion, v_user , v_RETURNED_SQLSTATE, v_MESSAGE_TEXT, v_MYSQL_ERRNO, v_Log, v_retNum, v_retTxt);
    commit;
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_mov_caducidad`( IN v_idApp 			BIGINT  
																 , IN v_user 			VARCHAR(45)		-- Usuario que lanza el procedimiento
																 , INOUT v_retNum 		INT				-- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																 , INOUT v_retTxt 		VARCHAR(4000)	-- Texto en caso de error (v_retNum < 0)
																 , IN  v_idParticipante BIGINT			-- Por si se queire cadudcar un único beneficiario
																 , IN  v_fecha 			VARCHAR(19)		-- '%Y-%m-%d' fecha de caducidad. De aquí hacia atrás se caduca todo
																 , IN  v_descripcion 	VARCHAR(250)	-- parte común de la Descripción para las operaciones de caducidad
																 , OUT v_saldoCaducado	DECIMAL(12,2)	-- Saldo total caducado
																 )
BEGIN
-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_mov_caducidad';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

    START TRANSACTION;
		Call mov_caducidad (v_idApp, v_user, v_retNum, v_retTxt, v_idParticipante, v_fecha, v_descripcion, v_saldoCaducado);
    commit;   
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_mov_consulta_a_caducar`( IN v_idApp 		BIGINT  
																 , IN v_user 				VARCHAR(45)		-- Usuario que lanza el procedimiento
																 , INOUT v_retNum 			INT				-- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																 , INOUT v_retTxt 			VARCHAR(4000)	-- Texto en caso de error (v_retNum < 0)
																 , IN    v_idParticipante	BIGINT     		-- beneficiario a conocer su saldo a caducar
																 , IN    v_fecha 			VARCHAR(19)		-- '%Y-%m-%d' fecha en la que se haría la caducidad. Si no se pone nada coge fin de mes actual
																 , OUT   v_saldoACaducar	DECIMAL(12,2)	-- Saldp total caducado
																 )
BEGIN
-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio w_mov_consulta_a_caducar';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

    START TRANSACTION;
		Call mov_consulta_a_caducar( v_idApp , v_user , v_retNum , v_retTxt , v_idParticipante , v_fecha , v_saldoACaducar);
    -- commit;   
    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_mov_crea_anula`(   IN v_idApp 			BIGINT  
																, IN v_user 			VARCHAR(45)         -- Usuario que lanza el procedimiento
																, INOUT v_retNum 		INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																, INOUT v_retTxt 		VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																, IN  v_idParticipante 	BIGINT          -- 
																, IN  v_idMov			BIGINT          -- 
																, IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																, IN  v_descripcion		VARCHAR(250)    -- 
																, IN  v_puntos 			DECIMAL(11,2)   -- 
																, IN  v_fichero 		VARCHAR(250)     -- 
																, OUT v_id   			BIGINT          -- ID de la operación creada
																, OUT v_saldo 			DECIMAL(11,2)   -- 
                                                        )
BEGIN
-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_mov_crea_anula';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;

    START TRANSACTION;
		Call mov_crea_anula(v_idApp , v_user , v_retNum , v_retTxt, v_idParticipante, v_idMov, v_fecha, v_descripcion, v_puntos, v_fichero, v_id, v_saldo);
		IF v_retNum = 0 Then
			commit;   
		END IF;    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_mov_crea_resta`(  IN v_idApp BIGINT  
																, IN v_user VARCHAR(45)         -- Usuario que lanza el procedimiento
																, INOUT v_retNum INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																, INOUT v_retTxt VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																, IN  v_idParticipante 	BIGINT          -- 
																, IN  v_idCentro 		BIGINT          -- 
																, IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																, IN  v_descripcion 	VARCHAR(250)    -- 
																, IN  v_puntos 			DECIMAL(11,2)   -- 
																, IN  v_fichero 		VARCHAR(250)     -- 
																, OUT v_id   			BIGINT          -- ID de la operación creada
																, OUT v_saldo 			DECIMAL(11,2)   -- 
                                                        )
BEGIN

DECLARE nIdConcepto BIGINT;
-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_mov_crea_resta';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;
    
    START TRANSACTION;
		Call mov_crea_resta(v_idApp, v_user , v_retNum, v_retTxt , v_idParticipante, v_idCentro, nIdConcepto, v_fecha, v_descripcion, v_puntos, v_fichero, v_id, v_saldo);

		IF v_retNum = 0 Then
			commit;   
		END IF;    
END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `madre`.`w_mov_crea_suma`(  IN v_idApp BIGINT  
																, IN v_user VARCHAR(45)         -- Usuario que lanza el procedimiento
																, INOUT v_retNum INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
																, INOUT v_retTxt VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
																, IN  v_idParticipante 	BIGINT          -- 
																, IN  v_idCentro 		BIGINT          -- 
																, IN  v_fecha 			VARCHAR(19)     -- '%Y-%m-%d %H:%i:%s'
																, IN  v_descripcion 	VARCHAR(250)    -- 
																, IN  v_puntos 			DECIMAL(11,2)   -- 
																, IN  v_fichero 		VARCHAR(250)     -- 
																, OUT v_id   			BIGINT          -- ID de la operación creada
																, OUT v_saldo 			DECIMAL(11,2)   -- 
                                                        )
BEGIN

DECLARE nIdConcepto BIGINT;
-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'Inicio_w_mov_crea_Suma';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
	End;

    SET v_retNum = null;
    SET v_retTxt = null;
    
    START TRANSACTION;
		Call mov_crea_suma(v_idApp, v_user , v_retNum, v_retTxt , v_idParticipante, v_idCentro, nIdConcepto, v_fecha, v_descripcion, v_puntos, v_fichero, v_id, v_saldo);

		IF v_retNum = 0 Then
			commit;   
		END IF;   
END;

CREATE DEFINER=`madre`@`localhost` PROCEDURE `madre`.`w_sem_crea_centro_y_contenido`( IN v_idApp 					BIGINT  
														, IN v_user 					VARCHAR(45)    -- Usuario que lanza el procedimiento
														, INOUT v_retNum 				INT            -- 0 --> OK; <0 --> error;  >0 --> Ok, con algún significado
														, INOUT v_retTxt 				VARCHAR(4000)  -- Texto en caso de error (v_retNum < 0)
														, IN  v_id_idioma 				bigint
														, IN  v_id_dispositivo			bigint
														, IN  v_fecha 					VARCHAR(19)    -- '%Y-%m-%d %H:%i:%s' Fecha en la que queremos que todo esté activo
                                                        
														-- •	fijos:
														, IN  v_entorno					VARCHAR(4)	-- "DEV" o "PROD". si no es PROD siempre lo toma como DEV

														-- •	Centro:
														, IN  v_ctr_id					BIGINT
														, IN  v_ctr_nombre				VARCHAR(100)
														, IN  v_ctr_provincia			INT
														, IN  v_ctr_contacto			VARCHAR(100)
														, IN  v_ctr_teléfono			VARCHAR(15)
														, IN  v_ctr_email				VARCHAR(100)
														, IN  v_ctr_id_empresa			BIGINT
														-- •	Contenidos de centro:
														, IN  v_ctr_cnt_nombre			VARCHAR(100)
														, IN  v_ctr_cnt_imagen			VARCHAR(200)
														, IN  v_ctr_cnt_intro			VARCHAR(4000)
														, IN  v_ctr_cnt_desc			VARCHAR(4000)
														, IN  v_ctr_cnt_horario			VARCHAR(100)
														, IN  v_ctr_cnt_contact_voucher	VARCHAR(100)
														, IN  v_ctr_cnt_dir_voucher		VARCHAR(100)
														-- •	Semillas (Experiencias):
														, IN  v_sem_nombre				VARCHAR(100)
														, IN  v_sem_categorias			JSON		   -- tipo '["7", "9", "10"]'
														-- •	Contenidos de Semillas:
														, IN  v_sem_cnt_nombre			VARCHAR(4000)
														, IN  v_sem_cnt_imagen			VARCHAR(4000)
														, IN  v_sem_cnt_intro			VARCHAR(4000)
														, IN  v_sem_cnt_desc 			VARCHAR(4000)
														, IN  v_sem_cnt_subtitulo		VARCHAR(4000)
														, IN  v_sem_cnt_inf_extendida	VARCHAR(4000)
														, IN  v_sem_cnt_link			VARCHAR(4000)
														, IN  v_sem_cnt_como_conseguirlo	VARCHAR(4000)
														, IN  v_sem_cnt_como_canjearlo	VARCHAR(4000)
														, IN  v_sem_cnt_resumen			VARCHAR(4000)
														, IN  v_sem_cnt_resumen_desc	VARCHAR(4000)
														, IN  v_sem_cnt_CCGG			VARCHAR(4000)
														, IN  v_sem_cnt_imagen_voucher	VARCHAR(200)
														, IN  v_sem_cnt_desc_servicio	VARCHAR(4000)
														, IN  v_sem_cnt_como_funciona	VARCHAR(4000)
														, IN  v_pwd						VARCHAR(15)
                                                        )
BEGIN

DECLARE nIdConcepto BIGINT;
-- -----------------------------------------------------------------------------------------------------
-- DECLARACIÓN de ERRORES
-- -----------------------------------------------------------------------------------------------------
DECLARE errorMySql      varchar(4000);
DECLARE errorNum        varchar(4000);
DECLARE errorText       varchar(4000);
DECLARE cDonde          varchar(4000) default 'w_sem_crea_centro_y_contenido';

DECLARE exit HANDLER FOR SQLEXCEPTION
	Begin
		GET DIAGNOSTICS CONDITION 1
			errorNum   = RETURNED_SQLSTATE,
 			errorText  = MESSAGE_TEXT,
            errorMySql = MYSQL_ERRNO;
		ROLLBACK;
		Call hxxi_crea_log(v_idApp , 'E', '2', v_user, errorNum, errorText, errorMySql, cDonde,  v_retNum, v_retTxt); 
		commit;
	End;

    SET v_retNum = null;
    SET v_retTxt = null;
    
    START TRANSACTION;
    SET v_retNum = 0;
    SET v_retTxt = "Creación de contenido realizada con éxito";

	Call sem_crea_centro_y_contenido(v_idApp, v_user , v_retNum, v_retTxt , v_id_idioma , v_id_dispositivo , v_fecha
													-- •	fijos:
													, v_entorno		

													-- •	Centro:
													, v_ctr_id					
													, v_ctr_nombre				
													, v_ctr_provincia			
													, v_ctr_contacto			
													, v_ctr_teléfono			
													, v_ctr_email				
													, v_ctr_id_empresa			
													-- •	Contenidos de centro:
													, v_ctr_cnt_nombre			
													, v_ctr_cnt_imagen			
													, v_ctr_cnt_intro			
													, v_ctr_cnt_desc			
													, v_ctr_cnt_horario			
													, v_ctr_cnt_contact_voucher	
													, v_ctr_cnt_dir_voucher		
													-- •	Semillas (Experiencias):
													, v_sem_nombre				
													, v_sem_categorias			
													-- •	Contenidos de Semillas:
													, v_sem_cnt_nombre			
													, v_sem_cnt_imagen			
													, v_sem_cnt_intro			
													, v_sem_cnt_desc 			
													, v_sem_cnt_subtitulo		
													, v_sem_cnt_inf_extendida	
													, v_sem_cnt_link			
													, v_sem_cnt_como_conseguirlo
													, v_sem_cnt_como_canjearlo	
													, v_sem_cnt_resumen			
													, v_sem_cnt_resumen_desc	
													, v_sem_cnt_CCGG			
													, v_sem_cnt_imagen_voucher	
													, v_sem_cnt_desc_servicio	
													, v_sem_cnt_como_funciona	
													, v_pwd
									);

		IF v_retNum = 0 Then
			commit;   
		END IF;
 
END;