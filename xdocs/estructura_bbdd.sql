-- Version: 20/05/2026
-- madre.cat_categorias definition

CREATE TABLE `cat_categorias` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `nombre` varchar(50) NOT NULL COMMENT 'Descripción corta',
  `descripcion` varchar(255) NOT NULL COMMENT 'Descripción larga',
  `orden` int(10) unsigned NOT NULL DEFAULT 0 COMMENT 'PAra una posible visualización ordenada',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cat_definicion definition

CREATE TABLE `cat_definicion` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `fec_inicio` timestamp NOT NULL DEFAULT current_timestamp(),
  `fec_fin` timestamp NULL DEFAULT NULL,
  `estado` int(11) NOT NULL DEFAULT 1 COMMENT '0-->Activo; 1-->Inactivo',
  `genesis_token` varchar(45) DEFAULT NULL COMMENT 'Token para conectar con la campaña correspondiente a través API de Génesis y canjear los códigos. ',
  `id_cdx` bigint(20) NOT NULL DEFAULT 0 COMMENT 'Si es una campaña de Codex, su ID, si es 0 es que no es campaña de CODEX',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cat_proveedores definition

CREATE TABLE `cat_proveedores` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) NOT NULL COMMENT 'Descripción corta o identificativo',
  `plt_descarga` varchar(45) DEFAULT 'estandar',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  `id_app` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cdx_campaigns_adicionales definition

CREATE TABLE `cdx_campaigns_adicionales` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_campaign` bigint(20) unsigned NOT NULL,
  `producto` set('D','F') DEFAULT NULL COMMENT 'Digital, Físico',
  `etiqueta` varchar(100) NOT NULL,
  `visibilidad` set('0','1','2') NOT NULL DEFAULT '0' COMMENT '0 -> no visible; 1 -> visible; 2 -> obligatorio',
  `repetir` int(11) NOT NULL DEFAULT 999999 COMMENT 'Veces que se puede repetir este campo en canjes de esta campaña.',
  `orden` int(11) NOT NULL DEFAULT 1 COMMENT 'Veces que se puede repetir este campo en canjes de esta campaña.',
  `lista` varchar(4000) DEFAULT NULL COMMENT 'Lista de valores separados por comas (si tiene comas el campo ha de ir entre comillas)',
  `js_validacion` varchar(4000) DEFAULT NULL COMMENT 'Js o plantilla: [{1:100}, {1,2,5,7,9}, {"A","Z"}, {js_dni}, {js_email}].... esto como quieras, una especie de regex y que se puedan meter funciones predefinidas js pra DNI, email, telf(tener en cuenta el pais)',
  `tipo_basico` set('D','E','F','H','T','C','L') DEFAULT 'C' COMMENT 'Decimal, Entero, Fecha, Hora, (T)Datetime, Caracter, Lógico',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_cdx_campaigns_adicionales_idx` (`id_campaign`)
) ENGINE=InnoDB AUTO_INCREMENT=81 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cdx_etiqueta_morphs definition

CREATE TABLE `cdx_etiqueta_morphs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `model_id` int(10) unsigned NOT NULL,
  `model_type` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `id_etiqueta` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `descripcion` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_bin;


-- madre.cdx_etiquetas definition

CREATE TABLE `cdx_etiquetas` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(20) NOT NULL COMMENT 'Nombre de la etiqueta',
  `descripcion` varchar(255) NOT NULL COMMENT 'En carga automática desde cdx_productos es el nombre del producto',
  `tipo` set('0','1') DEFAULT '0' COMMENT '0 --> Etiqueta privada, es decir, para poder asociar esta etiqueta a un producto deben tener el mismo nombre o ID o lo que se decida; 1 -> Etiqueta general, vale para todos los productos',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cdx_plantillas definition

CREATE TABLE `cdx_plantillas` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) NOT NULL,
  `origen` varchar(45) NOT NULL COMMENT 'de la tabla de cnt_def_contenidos',
  `clave` varchar(45) NOT NULL COMMENT 'de la tabla de cnt_def_contenidos',
  `template` varchar(45) NOT NULL COMMENT 'Nombre de la plantilla para la ruta de PHP',
  `modulo` set('CAT','CDX','XPR') NOT NULL DEFAULT 'CDX',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cdx_precodigos_envios definition

CREATE TABLE `cdx_precodigos_envios` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `id_precodigo` int(10) unsigned DEFAULT NULL,
  `id_envio` int(10) unsigned DEFAULT NULL,
  `tipo` varchar(45) DEFAULT NULL COMMENT 'mail o sms',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=122 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- madre.cdx_precodigos_estado definition

CREATE TABLE `cdx_precodigos_estado` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `id_precodigo` bigint(20) NOT NULL,
  `id_user` bigint(20) DEFAULT NULL,
  `estado` int(11) NOT NULL DEFAULT 0 COMMENT 'Estado del precódigo en el momento de la creación del registro: 0 CREADO, 1 INICIO DE SESIÓN, 2 RECHAZADO, ',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `id_precodigo` (`id_precodigo`),
  KEY `id_user` (`id_user`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cnt_def_contenidos definition

CREATE TABLE `cnt_def_contenidos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `origen` varchar(45) NOT NULL,
  `clave` varchar(45) NOT NULL,
  `descripcion` varchar(500) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `cnt_def_contenidos_Origen_clave_uk` (`origen`,`clave`)
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cnt_dispositivos definition

CREATE TABLE `cnt_dispositivos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(45) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cnt_tipo_campos definition

CREATE TABLE `cnt_tipo_campos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(45) NOT NULL,
  `validacion` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`validacion`)),
  `descripcion` varchar(4000) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.dir_ciudades definition

CREATE TABLE `dir_ciudades` (
  `latitud` double DEFAULT NULL,
  `name` text DEFAULT NULL,
  `created_at` text DEFAULT NULL,
  `updated_at` text DEFAULT NULL,
  `id` int(11) DEFAULT NULL,
  `state_id` int(11) DEFAULT NULL,
  `slug` text DEFAULT NULL,
  `longitud` double DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- madre.dir_direcciones definition

CREATE TABLE `dir_direcciones` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `tipo` set('1','2','3') NOT NULL DEFAULT '1' COMMENT '1 --> personal; 2 --> canje; 3 --> Fiscal (no se puede modificar)',
  `id_participante` bigint(20) unsigned DEFAULT NULL,
  `id_provincia` bigint(20) unsigned NOT NULL,
  `localidad` varchar(255) NOT NULL,
  `cp` varchar(25) NOT NULL,
  `direccion1` varchar(255) NOT NULL,
  `direccion2` varchar(255) DEFAULT NULL,
  `numero` varchar(15) DEFAULT NULL,
  `complemento` varchar(15) DEFAULT NULL,
  `portal_bloque` varchar(15) DEFAULT NULL,
  `escalera` varchar(15) DEFAULT NULL,
  `planta` varchar(15) DEFAULT NULL,
  `puerta` varchar(15) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.dir_paises definition

CREATE TABLE `dir_paises` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `codigo` varchar(25) NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.dir_provincias definition

CREATE TABLE `dir_provincias` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_pais` bigint(20) unsigned NOT NULL DEFAULT 0,
  `id_comunidad` bigint(20) unsigned NOT NULL DEFAULT 0,
  `codigo` varchar(25) NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=75 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.exp_campaigns_categorias definition

CREATE TABLE `exp_campaigns_categorias` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_campaign` bigint(20) unsigned NOT NULL,
  `id_categoria` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_xpr_campaigns_categorias_categorias_idx` (`id_categoria`),
  KEY `FK_exp_campaigns_categorias_cdx_campaigns_idx` (`id_campaign`)
) ENGINE=InnoDB AUTO_INCREMENT=39 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.exp_categorias definition

CREATE TABLE `exp_categorias` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) NOT NULL,
  `id_contenido` bigint(20) unsigned NOT NULL COMMENT 'el contenido es un ID directo al mismo, pero para cuando se crea el contenido debe ser con el ID_APP que se indica en la tabla de hxxi_canfiguracion para la aplicación=0 (superadministrador) y con nombre id_app_semillas',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.exp_experiencias definition

CREATE TABLE `exp_experiencias` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_contenido` bigint(20) unsigned NOT NULL COMMENT 'el contenido es un ID directo al mismo, pero para cuando se crea el contenido debe ser con el ID_APP que se indica en la tabla de hxxi_canfiguracion para la aplicación=0 (superadministrador) y con nombre id_app_semillas',
  `nombre` varchar(255) NOT NULL,
  `estado` set('0','1') NOT NULL DEFAULT '0' COMMENT '0 --> Inactiva; 1--> Activa',
  `desde` timestamp NOT NULL DEFAULT current_timestamp(),
  `hasta` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.exp_experiencias_centros definition

CREATE TABLE `exp_experiencias_centros` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_experiencia` bigint(20) unsigned NOT NULL,
  `id_centro` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_exp_experiencias_centros_experiencias_idx` (`id_experiencia`),
  KEY `FK_exp_experiencias_centros_centros_idx` (`id_centro`)
) ENGINE=InnoDB AUTO_INCREMENT=152 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.failed_jobs definition

CREATE TABLE `failed_jobs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(255) NOT NULL,
  `connection` text NOT NULL,
  `queue` text NOT NULL,
  `payload` longtext NOT NULL,
  `exception` longtext NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_APIs definition

CREATE TABLE `hxxi_APIs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT 'se asocia con aplicaciones pero no se indica FK para no penalizar',
  `metodo` varchar(100) NOT NULL,
  `accion` char(1) NOT NULL COMMENT 'I --> In; O --> Out',
  `log` varchar(4000) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=145977 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_api_tokens definition

CREATE TABLE `hxxi_api_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) NOT NULL COMMENT 'Tipo de modelo al que se le asigna el token',
  `tokenable_id` bigint(20) unsigned NOT NULL COMMENT 'Id del modelo al que se le asigna el token',
  `name` varchar(255) NOT NULL COMMENT 'Nombre amigable para identificar el token',
  `token` varchar(64) NOT NULL,
  `abilities` text DEFAULT NULL COMMENT 'Habilidades que tendrá el token',
  `last_used_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `hxxi_api_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de api tokens de usos generales';


-- madre.hxxi_fichero_carga definition

CREATE TABLE `hxxi_fichero_carga` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `fichero` varchar(200) NOT NULL,
  `nombre` varchar(200) NOT NULL,
  `status` set('0','1','2') DEFAULT NULL COMMENT '0-> Pendiente de procesar\n1-> Procesado\n2-> Error',
  `comentarios` text DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_idiomas definition

CREATE TABLE `hxxi_idiomas` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(45) NOT NULL,
  `ansi` varchar(5) DEFAULT NULL,
  `idioma` char(2) DEFAULT NULL,
  `pais` char(2) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_log definition

CREATE TABLE `hxxi_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT 'se asocia con aplicaciones pero no se indica FK para no penalizar',
  `tipo` set('A','E','I') NOT NULL DEFAULT 'E' COMMENT '''A'' --> Aviso;  ''E'' --> Error; ''I'' --> Incidencia',
  `accion` char(1) NOT NULL DEFAULT '0' COMMENT '0 --> No ha roto el proceso ni la función en la que se ejecuta; 1 --> la función que se ejecuta, se ha quedado a medias en algún lugar; 2 --> se ha debido romper el proceso',
  `log` varchar(4000) NOT NULL,
  `err_mysql` varchar(45) DEFAULT NULL COMMENT 'err_mysql = MYSQL_ERRNO',
  `error_num` varchar(45) DEFAULT NULL COMMENT 'error_num = RETURNED_SQLSTATE',
  `error_text` varchar(4000) DEFAULT NULL COMMENT 'error_text = MESSAGE_TEXT',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=90070 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_paises definition

CREATE TABLE `hxxi_paises` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `pais` varchar(255) NOT NULL,
  `codigo` varchar(2) NOT NULL COMMENT 'es, pt, fr',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_password_resets definition

CREATE TABLE `hxxi_password_resets` (
  `id_app` int(11) DEFAULT NULL,
  `email` varchar(255) NOT NULL,
  `token` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  KEY `password_resets_email_index` (`id_app`,`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_permisos definition

CREATE TABLE `hxxi_permisos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `guard_name` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_roles definition

CREATE TABLE `hxxi_roles` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `guard_name` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.mail_access_token definition

CREATE TABLE `mail_access_token` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) NOT NULL,
  `id_app` bigint(20) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `token` varchar(64) NOT NULL,
  `abilities` text DEFAULT NULL,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  KEY `mail_access_tokens_tokenable_type_app_id_index` (`tokenable_type`,`id_app`)
) ENGINE=InnoDB AUTO_INCREMENT=87 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.mail_adjuntos definition

CREATE TABLE `mail_adjuntos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `url` varchar(500) NOT NULL COMMENT 'url o directorio donde se encuentra el fichero.',
  `nombre_fichero` varchar(255) NOT NULL,
  `long_fichero` decimal(12,2) DEFAULT NULL,
  `mime_type` varchar(255) DEFAULT NULL,
  `extension` varchar(10) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.mail_app_servidores definition

CREATE TABLE `mail_app_servidores` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `id_servidor` bigint(20) unsigned NOT NULL,
  `tipo` set('M','P','T') NOT NULL DEFAULT 'T' COMMENT 'M --> Envíos masivos; P -> Promocional; T --> transaccional',
  `activo` set('S','N') NOT NULL DEFAULT 'S' COMMENT 'Este servidor está activo o no. De tipo "T" siempre debe haber alguno activo.',
  `orden_servidor` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.mail_servidores definition

CREATE TABLE `mail_servidores` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(50) NOT NULL,
  `charset` varchar(50) NOT NULL DEFAULT 'utf8',
  `descripcion` varchar(255) DEFAULT NULL,
  `nombre_clase` varchar(180) NOT NULL,
  `nombre_servicio` varchar(90) NOT NULL,
  `orden_servidor` tinyint(4) NOT NULL DEFAULT 0,
  `de` varchar(255) NOT NULL,
  `de_nombre` varchar(255) NOT NULL,
  `reply_to` varchar(255) NOT NULL,
  `ip` varchar(25) DEFAULT NULL,
  `puerto` varchar(255) NOT NULL,
  `host` varchar(255) NOT NULL,
  `usuario` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `credenciales` varchar(2000) DEFAULT NULL COMMENT 'Credenciales especificas de cada servicio y que no están contempladas en los campos estandar de la tablka',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci COMMENT='Servidores que se van a usar Sendiblue, amazon teenvio,....';


-- madre.menu_acciones definition

CREATE TABLE `menu_acciones` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `tipo` varchar(45) DEFAULT NULL COMMENT 'N --> es necesario tener la opción para ejecutarla\nP --> Publica, es decir, No se tiene que tener la acción para ejecutarla',
  `slug` varchar(255) NOT NULL COMMENT 'Identificador único de la URL',
  `label` varchar(255) DEFAULT NULL COMMENT 'sería una descripción',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.password_resets definition

CREATE TABLE `password_resets` (
  `email` varchar(255) NOT NULL,
  `token` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  KEY `password_resets_email_index` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.personal_access_tokens definition

CREATE TABLE `personal_access_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `tokenable_id` bigint(20) unsigned NOT NULL,
  `name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `abilities` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  KEY `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_bin;


-- madre.sms_servidores definition

CREATE TABLE `sms_servidores` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(50) NOT NULL,
  `charset` varchar(50) NOT NULL,
  `descripcion` varchar(255) NOT NULL,
  `de` varchar(255) NOT NULL,
  `de_nombre` varchar(255) DEFAULT NULL,
  `ip` varchar(25) DEFAULT NULL,
  `puerto` varchar(255) NOT NULL,
  `host` varchar(255) NOT NULL,
  `nombre_clase` varchar(180) DEFAULT NULL,
  `nombre_servicio` varchar(90) DEFAULT NULL,
  `usuario` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `credenciales` varchar(2000) DEFAULT NULL COMMENT 'Credenciales especificas de cada servicio y que no están contempladas en los campos estandar de la tablka',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.cat_campos definition

CREATE TABLE `cat_campos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_cat` bigint(20) unsigned NOT NULL,
  `tipo_prod` set('0','1','2') NOT NULL DEFAULT '0' COMMENT '0 --> Digital; 1 --> Físico;  2 --> Otros',
  `visibilidad` set('0','1','2') NOT NULL DEFAULT '0' COMMENT '0 -> no visible; 1 -> visible; 2 -> obligatorio',
  `etiqueta` varchar(100) NOT NULL,
  `repetir` int(11) NOT NULL DEFAULT 999999 COMMENT 'Veces que se puede repetir este campo en canjes.',
  `Valida` varchar(4000) DEFAULT NULL COMMENT 'Por formato: [v1..v2] --> indica que el valor que puede tener debe estar entre V1 y V2; [v1;v2;v3] --> son los valores que puede tener ese campo y que salgan en una lista; ![] --> cualquiera de los anteriores pero negado; Si es una cobinación, pe: [1..10][12;14;16] no sacaría lista y dejaría intrducir solo los valores indicados; tendrá mas....',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_cat_campos_catalogo_idx` (`id_cat`),
  CONSTRAINT `fk_cat_campos_catalogo` FOREIGN KEY (`id_cat`) REFERENCES `cat_definicion` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Campos que se han de pedir en los productos de este catálogo, dependiento del tipo. En el formulario del BO que por defecto siempre se cree los siguientes registros por defecto: Nombre (1),  Email (2). Luego el usaurio podrá crear, modificar o eliminar';


-- madre.cnt_def_campos definition

CREATE TABLE `cnt_def_campos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_def_contenido` bigint(20) unsigned NOT NULL,
  `id_tipo_campo` bigint(20) unsigned NOT NULL,
  `orden` bigint(20) DEFAULT NULL COMMENT 'Orden del campo para sacar en el BO para su contenido.',
  `orden_grupo` varchar(45) NOT NULL DEFAULT '1. General' COMMENT 'Para saber en el frontal o formulario automatizado dónde se visualizan estos datos, dónde hay que sacarlos o si hay que sacarlos, es decir, el formulario dinámico saca toda la información, en el orden establecido: Alfanumérico para el grupo y dentro del grupo, por el campo orden.\n\nEn un formulario general, que saque todo de forma automática, este campo sería el título del grupo de campos y el orden. Aunque se puede hacer que en un formulario algo mas especifico, saque cada grupo de forma dinámica en diferentes sitios o incluso no sacar',
  `nombre` varchar(255) NOT NULL,
  `prompt` varchar(45) NOT NULL,
  `validacion` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`validacion`)),
  `tooltip` varchar(500) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `cnt_def_campos_id_def_contenido_foreign` (`id_def_contenido`),
  KEY `cnt_def_campos_id_tipo_campo_foreign` (`id_tipo_campo`),
  CONSTRAINT `cnt_def_campos_id_def_contenido_foreign` FOREIGN KEY (`id_def_contenido`) REFERENCES `cnt_def_contenidos` (`id`),
  CONSTRAINT `cnt_def_campos_id_tipo_campo_foreign` FOREIGN KEY (`id_tipo_campo`) REFERENCES `cnt_tipo_campos` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2009 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.dir_comunidades definition

CREATE TABLE `dir_comunidades` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_pais` bigint(20) unsigned NOT NULL,
  `codigo` varchar(25) NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_dir_comunidades_paises_idx` (`id_pais`),
  CONSTRAINT `fk_dir_comunidades_paises` FOREIGN KEY (`id_pais`) REFERENCES `dir_paises` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.exp_categorias_experiencias definition

CREATE TABLE `exp_categorias_experiencias` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_experiencia` bigint(20) unsigned NOT NULL,
  `id_categoria` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_exp_experiencias_categorias_experiencias_idx` (`id_experiencia`),
  CONSTRAINT `FK_exp_experiencias_categorias_experiencias` FOREIGN KEY (`id_experiencia`) REFERENCES `exp_experiencias` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1036 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_aplicaciones definition

CREATE TABLE `hxxi_aplicaciones` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_pais` bigint(20) unsigned NOT NULL,
  `tipo` set('0','1','2') NOT NULL DEFAULT '' COMMENT '0 --> Normal; 1 --> Administradores de País; 2 --> Administradores generales',
  `nombre` varchar(255) NOT NULL,
  `logo` text DEFAULT NULL,
  `public_key` varchar(45) DEFAULT NULL,
  `private_key` varchar(45) DEFAULT NULL,
  `iv` varchar(45) DEFAULT NULL,
  `password` varchar(45) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_aplicaciones_paises` (`id_pais`),
  CONSTRAINT `fk_aplicaciones_paises` FOREIGN KEY (`id_pais`) REFERENCES `hxxi_paises` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=64 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_configuracion definition

CREATE TABLE `hxxi_configuracion` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `grupo` varchar(45) NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `orden` tinyint(4) NOT NULL DEFAULT 0,
  `label` varchar(100) DEFAULT NULL,
  `valor` varchar(4000) DEFAULT NULL,
  `tooltip` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `xxi_configuracion_nombre_idx` (`id_app`,`grupo`,`nombre`),
  KEY `fk_hxxi_configuracion_aplicaciones_idx` (`id_app`),
  CONSTRAINT `fk_hxxi_configuracion_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=532 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_grupos definition

CREATE TABLE `hxxi_grupos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_hxxi_grupos_aplicaciones` (`id_app`),
  CONSTRAINT `fk_hxxi_grupos_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_recurso_permiso definition

CREATE TABLE `hxxi_recurso_permiso` (
  `permission_id` bigint(20) unsigned NOT NULL,
  `model_type` varchar(255) NOT NULL,
  `model_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`permission_id`,`model_id`,`model_type`),
  KEY `model_has_permissions_model_id_model_type_index` (`model_id`,`model_type`),
  CONSTRAINT `hxxi_recurso_permiso_permission_id_foreign` FOREIGN KEY (`permission_id`) REFERENCES `hxxi_permisos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_recurso_rol definition

CREATE TABLE `hxxi_recurso_rol` (
  `role_id` bigint(20) unsigned NOT NULL,
  `model_type` varchar(255) NOT NULL,
  `model_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`role_id`,`model_id`,`model_type`),
  KEY `model_has_roles_model_id_model_type_index` (`model_id`,`model_type`),
  CONSTRAINT `hxxi_recurso_rol_role_id_foreign` FOREIGN KEY (`role_id`) REFERENCES `hxxi_roles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_rol_permiso definition

CREATE TABLE `hxxi_rol_permiso` (
  `permission_id` bigint(20) unsigned NOT NULL,
  `role_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`permission_id`,`role_id`),
  KEY `hxxi_rol_permiso_role_id_foreign` (`role_id`),
  CONSTRAINT `hxxi_rol_permiso_permission_id_foreign` FOREIGN KEY (`permission_id`) REFERENCES `hxxi_permisos` (`id`) ON DELETE CASCADE,
  CONSTRAINT `hxxi_rol_permiso_role_id_foreign` FOREIGN KEY (`role_id`) REFERENCES `hxxi_roles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_users definition

CREATE TABLE `hxxi_users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `last_name` varchar(255) NOT NULL DEFAULT 'Apellido',
  `email` varchar(255) NOT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `status` tinyint(1) DEFAULT 0 COMMENT '0 --> habilitado; 1 --> inhabilitado',
  `password` varchar(255) NOT NULL,
  `id_item` bigint(20) DEFAULT NULL,
  `remember_token` varchar(100) DEFAULT NULL,
  `public_key` varchar(45) DEFAULT NULL,
  `private_key` varchar(45) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_hxxi_users_email_unique` (`id_app`,`email`),
  CONSTRAINT `fk_hxxi_users_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=48 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_users_app definition

CREATE TABLE `hxxi_users_app` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_user` bigint(20) unsigned NOT NULL,
  `id_app` bigint(20) unsigned NOT NULL COMMENT 'Si es cero, no es que pueda ver datos de id_app=0,  es que puede ver todas las aplicaciones, aunque aquí no tenga ningún registro o solo tenga el principal',
  `principal` set('S','N') NOT NULL DEFAULT 'N' COMMENT 'S --> Principal y debe coincidir con hxxi_users.id_app; N --> no es el principal y no puede coincidir con hxxi_users.id_app',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `hxxi_users_app_users_FK_idx` (`id_user`),
  KEY `hxxi_users_app_aplicaciones_FK_idx` (`id_app`),
  CONSTRAINT `hxxi_users_app_aplicaciones_FK` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `hxxi_users_app_users_FK` FOREIGN KEY (`id_user`) REFERENCES `hxxi_users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=48 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de relación entre los usuarios existentes y a los datos de que aplicaciones tienen acceso';


-- madre.mail_aplicaciones definition

CREATE TABLE `mail_aplicaciones` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `descripcion` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_mail_aplicaciones_hxxi_aplicaciones_idx` (`id_app`),
  CONSTRAINT `fk_mail_aplicaciones_hxxi_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=64 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.mail_envios definition

CREATE TABLE `mail_envios` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `id_sender` bigint(20) unsigned NOT NULL,
  `id_servidor` bigint(20) unsigned NOT NULL,
  `id_participante` bigint(20) unsigned NOT NULL COMMENT 'id con la tabla de hxxi_particiapantes, aunque no vamos a hacer FK porque de momento no vamos a comprobar que exista realmente',
  `estado` set('P','E','R','O','L') NOT NULL DEFAULT 'P' COMMENT '''P''endiente de enviar;  ''E''rror de envío;  ''R''eintentar;  ''O''K; ''L''ista Robinson',
  `para` varchar(255) NOT NULL,
  `para_nombre` varchar(255) DEFAULT NULL,
  `de` varchar(255) NOT NULL,
  `de_nombre` varchar(255) DEFAULT NULL,
  `cc` longtext DEFAULT NULL,
  `bcc` longtext DEFAULT NULL,
  `prioridad` int(2) NOT NULL DEFAULT 3,
  `reply_to` varchar(255) DEFAULT NULL,
  `clave_externa` varchar(255) DEFAULT NULL,
  `asunto` varchar(255) NOT NULL,
  `cuerpo` longtext NOT NULL,
  `lenguaje` varchar(255) NOT NULL,
  `parametros` longtext DEFAULT NULL,
  `fecha_envio` datetime NOT NULL DEFAULT current_timestamp(),
  `fecha_enviado` datetime DEFAULT NULL,
  `error` longtext DEFAULT NULL COMMENT 'Cuando estamos en error o en reintento aquí tendremos el texto correspondiente al error. Ya sea propio de del proveedor de servicios. Es un texto acumulativo, no borra lo anterior.',
  `identificador_externo` varchar(255) DEFAULT NULL COMMENT 'Identificador del envío en el proveedor de servicios. puede ser un compuesto de varios IDs en el proveedor',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_mail_envios_aplicaciones_idx` (`id_app`),
  CONSTRAINT `fk_mail_envios_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `mail_aplicaciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=670 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.mail_envios_adjuntos definition

CREATE TABLE `mail_envios_adjuntos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_envio` bigint(20) unsigned NOT NULL,
  `id_adjunto` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `mail_envios_adjuntos_mail_FK_idx` (`id_envio`),
  KEY `mail_envios_adjuntos_adjuntos_FK_idx` (`id_adjunto`),
  CONSTRAINT `mail_envios_adjuntos_adjuntos_FK` FOREIGN KEY (`id_adjunto`) REFERENCES `mail_adjuntos` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `mail_envios_adjuntos_envios_FK` FOREIGN KEY (`id_envio`) REFERENCES `mail_envios` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.mail_robinson definition

CREATE TABLE `mail_robinson` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `email` varchar(255) NOT NULL,
  `nivel` set('M','P','T') NOT NULL DEFAULT 'T' COMMENT 'nivel de robinson: M --> Envíos masivos; P -> Promocional; T --> Todos',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_mail_robinson_mail_nivel` (`email`,`nivel`),
  KEY `idx_mail_robinson_app` (`id_app`),
  CONSTRAINT `fk_mail_robinson_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `mail_aplicaciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.menu_acciones_users definition

CREATE TABLE `menu_acciones_users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_accion` bigint(20) unsigned NOT NULL,
  `id_user` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_menu_items_users_acciones_idx` (`id_accion`),
  KEY `fk_menu_acciones_users_users` (`id_user`),
  CONSTRAINT `fk_menu_acciones_users_acciones` FOREIGN KEY (`id_accion`) REFERENCES `menu_acciones` (`id`),
  CONSTRAINT `fk_menu_acciones_users_users` FOREIGN KEY (`id_user`) REFERENCES `hxxi_users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=155 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.menu_menus definition

CREATE TABLE `menu_menus` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `posicion` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `menus_position_unique` (`id_app`,`posicion`),
  CONSTRAINT `fk_menus_hxxi_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.mov_conceptos definition

CREATE TABLE `mov_conceptos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_concepto` bigint(20) unsigned NOT NULL,
  `id_app` bigint(20) unsigned NOT NULL,
  `tipo` set('B','U','A','C') NOT NULL DEFAULT 'B' COMMENT '''B''ásico;  \n''U''so o Canje;  \n''A''nulación;  \n''C''aducidad;  ',
  `descripcion` varchar(250) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_mov_conceptos_conceptos_aplicacion` (`id_concepto`,`id_app`),
  KEY `fk_mov_conceptos_hxxi_aplicaciones` (`id_app`),
  CONSTRAINT `fk_mov_conceptos_hxxi_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.sms_aplicaciones definition

CREATE TABLE `sms_aplicaciones` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `descripcion` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_smsaplicaciones_app_idx` (`id_app`),
  CONSTRAINT `fk_smsaplicaciones_app` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=59 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.sms_app_servidores definition

CREATE TABLE `sms_app_servidores` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `id_servidor` bigint(20) unsigned NOT NULL,
  `tipo` set('M','P','T') NOT NULL DEFAULT 'T' COMMENT 'M --> Envíos masivos; P -> Promocional; T --> transaccional',
  `activo` set('S','N') NOT NULL DEFAULT 'S' COMMENT 'Este servidor está activo o no. De tipo "T" siempre debe haber alguno activo.',
  `orden_servidor` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `sms_app_servidores_app_FK_idx` (`id_app`),
  KEY `sms_app_servidores_servidores_FK_idx` (`id_servidor`),
  CONSTRAINT `sms_app_servidores_app_FK` FOREIGN KEY (`id_app`) REFERENCES `sms_aplicaciones` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `sms_app_servidores_servidores_FK` FOREIGN KEY (`id_servidor`) REFERENCES `sms_servidores` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.sms_envios definition

CREATE TABLE `sms_envios` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `id_participante` bigint(20) unsigned NOT NULL COMMENT 'id con la tabla de hxxi_particiapantes, aunque no vamos a hacer FK porque de momento no vamos a comprobar que exista realmente',
  `id_servidor` bigint(20) unsigned NOT NULL,
  `telefono` varchar(20) NOT NULL COMMENT 'Telefono con el prefijo telefónico. formato: XXXX-YYYYYYYYYYYYYYY, por ejemplo: 0034-666593388 para un teléfono de España',
  `de` varchar(255) NOT NULL,
  `de_nombre` varchar(255) DEFAULT NULL,
  `prioridad` int(2) NOT NULL DEFAULT 3,
  `estado` set('P','E','R','O') NOT NULL DEFAULT 'P' COMMENT '''P''endiente de enviar;  \\n''E''rror de envío;  \\n''R''eintentar;  \\n''O''K;',
  `contenido` varchar(500) NOT NULL,
  `parametros` longtext DEFAULT NULL,
  `fecha_envio` datetime NOT NULL DEFAULT current_timestamp(),
  `fecha_enviado` datetime DEFAULT NULL,
  `error` longtext DEFAULT NULL COMMENT 'Cuando estamos en error o en reintento aquí tendremos el texto correspondiente al error. Ya sea propio de del proveedor de servicios. Es un texto acumulativo, no borra lo anterior.',
  `identificador_externo` varchar(255) DEFAULT NULL COMMENT 'Identificador del envío en el proveedor de servicios. puede ser un compuesto de varios IDs en el proveedor',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sms_envios_estados` (`estado`),
  KEY `fk_sms_envios_servidores_idx` (`id_servidor`),
  KEY `fk_sms_envios_aplicaciones_idx` (`id_app`),
  CONSTRAINT `fk_sms_envios_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `sms_aplicaciones` (`id`),
  CONSTRAINT `fk_sms_envios_servidores` FOREIGN KEY (`id_servidor`) REFERENCES `sms_servidores` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.sms_robinson definition

CREATE TABLE `sms_robinson` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `telefono` varchar(20) NOT NULL,
  `nivel` set('M','P','T') NOT NULL DEFAULT 'T' COMMENT 'nivel de robinson: M --> Envíos masivos; P -> Promocional; T --> Todos',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_sms_robinson_telf_nivel` (`telefono`,`nivel`),
  KEY `fk_sms_robinson_aplicaciones_idx` (`id_app`),
  CONSTRAINT `fk_sms_robinson_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `sms_aplicaciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


-- madre.cnt_contenidos definition

CREATE TABLE `cnt_contenidos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `id_def_contenido` bigint(20) unsigned NOT NULL,
  `descripcion` varchar(1000) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `cnt_contenidos_id_def_contenido_foreign` (`id_def_contenido`),
  KEY `fk_cnt_contenidos_id_app_idx` (`id_app`),
  CONSTRAINT `cnt_contenidos_id_def_contenido_foreign` FOREIGN KEY (`id_def_contenido`) REFERENCES `cnt_def_contenidos` (`id`),
  CONSTRAINT `fk_cnt_contenidos_id_app` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=656 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cnt_posiciona definition

CREATE TABLE `cnt_posiciona` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_cnt_contenidos` bigint(20) unsigned NOT NULL,
  `desde` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `hasta` datetime DEFAULT NULL,
  `id_idioma` bigint(20) unsigned NOT NULL DEFAULT 0,
  `id_dispositivo` bigint(20) unsigned NOT NULL DEFAULT 0,
  `descripcion` varchar(500) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `cnt_posiciona_id_cnt_contenidos_foreign` (`id_cnt_contenidos`),
  KEY `cnt_posiciona_id_dispositivo_foreign` (`id_dispositivo`),
  KEY `cnt_posiciona_id_idioma_foreign` (`id_idioma`),
  CONSTRAINT `cnt_posiciona_id_cnt_contenidos_foreign` FOREIGN KEY (`id_cnt_contenidos`) REFERENCES `cnt_contenidos` (`id`),
  CONSTRAINT `cnt_posiciona_id_dispositivo_foreign` FOREIGN KEY (`id_dispositivo`) REFERENCES `cnt_dispositivos` (`id`),
  CONSTRAINT `cnt_posiciona_id_idioma_foreign` FOREIGN KEY (`id_idioma`) REFERENCES `hxxi_idiomas` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=649 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cnt_valores definition

CREATE TABLE `cnt_valores` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_posiciona` bigint(20) unsigned NOT NULL DEFAULT 1,
  `id_def_contenido` bigint(20) unsigned NOT NULL,
  `id_def_campo` bigint(20) unsigned NOT NULL,
  `valor1` text DEFAULT NULL,
  `valor2` text DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `cnt_valores_id_def_campo_foreign` (`id_def_campo`),
  KEY `cnt_valores_id_def_contenido_foreign` (`id_def_contenido`),
  KEY `cnt_valores_id_posiciona_foreign` (`id_posiciona`),
  CONSTRAINT `cnt_valores_id_def_campo_foreign` FOREIGN KEY (`id_def_campo`) REFERENCES `cnt_def_campos` (`id`),
  CONSTRAINT `cnt_valores_id_def_contenido_foreign` FOREIGN KEY (`id_def_contenido`) REFERENCES `cnt_def_contenidos` (`id`),
  CONSTRAINT `cnt_valores_id_posiciona_foreign` FOREIGN KEY (`id_posiciona`) REFERENCES `cnt_posiciona` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6188 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.menu_items definition

CREATE TABLE `menu_items` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_menu` bigint(20) unsigned NOT NULL COMMENT 'Solo si es de menú.',
  `title` varchar(255) NOT NULL COMMENT 'Solo si es de menú.',
  `label` varchar(255) DEFAULT NULL COMMENT 'Para el tooltip si es de menú, si no lo es, sería una descripción',
  `route_name` varchar(255) DEFAULT NULL COMMENT 'Nombre de la ruta existente de la aplicacion para el item',
  `title_section` varchar(255) DEFAULT NULL,
  `url` varchar(255) DEFAULT NULL COMMENT 'URL fijo del item',
  `_lft` int(10) unsigned NOT NULL DEFAULT 0 COMMENT 'Solo si es de menú.',
  `_rgt` int(10) unsigned NOT NULL DEFAULT 0 COMMENT 'Solo si es de menú.',
  `parent_id` int(10) unsigned DEFAULT NULL COMMENT 'Solo si es de menú.',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `menu_items__lft__rgt_parent_id_index` (`_lft`,`_rgt`,`parent_id`),
  KEY `menu_items_menu_id_foreign` (`id_menu`),
  CONSTRAINT `fk_menu_items_menus` FOREIGN KEY (`id_menu`) REFERENCES `menu_menus` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=149 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.menu_items_users definition

CREATE TABLE `menu_items_users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_item` bigint(20) unsigned NOT NULL,
  `id_user` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_menu_items_users_items_idx` (`id_item`),
  KEY `fk_menu_items_users_users_idx` (`id_user`),
  CONSTRAINT `fk_menu_items_users_items` FOREIGN KEY (`id_item`) REFERENCES `menu_items` (`id`),
  CONSTRAINT `fk_menu_items_users_users` FOREIGN KEY (`id_user`) REFERENCES `hxxi_users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=408 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cat_productos definition

CREATE TABLE `cat_productos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `id_proveedor` bigint(20) unsigned NOT NULL,
  `id_contenido` bigint(20) unsigned NOT NULL COMMENT 'Id del tipo de contenido que tiene todos los datos descriptivos del producto, no tiene FK contra la tabla de cnt_contenidos pero debe existir ahí',
  `tipo_prod` set('0','1','2') NOT NULL DEFAULT '0' COMMENT '0 --> Digital; 1 --> Físico;  2 --> Otros',
  `tipo_canje` set('0','1','2') NOT NULL DEFAULT '0' COMMENT '0 --> Normal (canjea el producto, envía correo..... ciclo completo de canje); 1--> Indirecto (Canjea, pero no envía el email, saca mensaje de que se realizará en la próximas XX horas y el tramita por otra vía); 2 —> Producto genérico (uso futuro). es un producto especial para campañas de productos genéricos, que solo enseñan este tipo de productos en el frontal, por ejemplo, Amazon, VISA,... pero no con un valor específico. Los normales se visualizan en el BO para que un gestor los seleccione',
  `nombre` varchar(255) NOT NULL,
  `opciones_compra` varchar(500) NOT NULL COMMENT 'array [descripción:valor] con las opciones de compra de un producto. Por ejemplo producto Amazon de 25, 50, 75€. Si tiene varias opciones de compra habría que sacarlo en el frontal. p.e.: ["25€":"25";"50€":"50";"75€":"75"]',
  `stock` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT 'Estimativo',
  `id_producto_genesis` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  `principal` tinyint(1) DEFAULT 0,
  `generico` tinyint(1) DEFAULT 0,
  `manual` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `cat_cat_productos_proveedores_idx` (`id_proveedor`),
  KEY `fk_cat_productos_cnt_contenido_idx` (`id_contenido`),
  KEY `fk_cat_productos_hxxi_aplicaciones_idx` (`id_app`),
  CONSTRAINT `fk_cat_productos_cnt_contenido` FOREIGN KEY (`id_contenido`) REFERENCES `cnt_contenidos` (`id`),
  CONSTRAINT `fk_cat_productos_hxxi_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`),
  CONSTRAINT `fk_cat_productos_proveedores` FOREIGN KEY (`id_proveedor`) REFERENCES `cat_proveedores` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de productos que utiliza el sistema para el canje.';


-- madre.cdx_frontales definition

CREATE TABLE `cdx_frontales` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `id_plantilla` bigint(20) unsigned NOT NULL DEFAULT 1,
  `id_contenido` bigint(20) unsigned DEFAULT NULL COMMENT 'Id del contenido (Tablas de contenido) que contienen todo el contenido por defecto de este frontal para sus campañas',
  `tipo` set('estandar','personalizado') DEFAULT 'estandar',
  `dominio` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT 'Dominio o subdominio de este frontal. Sirve para que en caso de un servidor que tenga varios frontales desplegados, sepa a que frontal nos referimos. A no ser que sea una campaña de premio_directo',
  `nombre` varchar(255) NOT NULL,
  `status` set('1','2') NOT NULL DEFAULT '1' COMMENT 'Activo (1), desactivado (2) por lo que no se puede entrar en ninguno de sus frontales',
  `modulo` set('CAT','CDX','XPR','CAM') NOT NULL DEFAULT 'CDX',
  `descripcion` varchar(400) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cdx_frontales_name_unique` (`id_app`,`nombre`),
  KEY `fk_cdx_frontales_cnt_contenidos_idx` (`id_contenido`),
  KEY `fk_cdx_frontales_plantillas` (`id_plantilla`),
  CONSTRAINT `fk_cdx_frontales_cnt_contenidos` FOREIGN KEY (`id_contenido`) REFERENCES `cnt_contenidos` (`id`),
  CONSTRAINT `fk_cdx_frontales_hxxi_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`),
  CONSTRAINT `fk_cdx_frontales_plantillas` FOREIGN KEY (`id_plantilla`) REFERENCES `cdx_plantillas` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cat_cat_productos definition

CREATE TABLE `cat_cat_productos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_cat` bigint(20) unsigned NOT NULL,
  `id_producto` bigint(20) unsigned NOT NULL,
  `id_categoría` bigint(20) unsigned DEFAULT NULL,
  `id_contenido` bigint(20) unsigned DEFAULT NULL COMMENT 'En principio el del producto, pero en cuanto se cambie, se debe crear uno nuevo y unico para este producto en esta campaña, en el momento se que cambia, ya no coge valores del original, es decir, si tengo un producto amazon que tiene una descripción condiciones, etc, en el momento que se cree algo especial para este producto en esta campaña, aunque se cambie algo en el "master" de cat_productos, aquí no tendrá reflejo.',
  `max_campana` bigint(20) NOT NULL DEFAULT 500 COMMENT 'Máximo de productos que se van a permitir canjear en la campaña',
  `orden` int(11) NOT NULL DEFAULT 0 COMMENT 'Orden de salida del producto en el catálogo',
  `opciones_compra` varchar(500) DEFAULT NULL COMMENT 'array [descripción:valor] con las opciones de compra de un producto. Por ejemplo producto Amazon de 25, 50, 75€. Si tiene varias opciones de compra habría que sacarlo en el frontal. p.e.: ["25€":"25";"50€":"50";"75€":"75"]; Descipción es el literal a sacar en pantalla, el valor son los puntos a descontar al usuario de su saldo su canjea por este producto',
  `estado` set('0','1') NOT NULL DEFAULT '0' COMMENT '0-->Activo; 1-->Inactivo',
  `id_producto_genesis` bigint(20) DEFAULT NULL,
  `principal` set('N','P') NOT NULL DEFAULT 'N' COMMENT 'Normal, Principal',
  `link_personalizado` varchar(150) DEFAULT NULL,
  `texto_link_personalizado` varchar(500) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_cat_cat_productos_idx` (`id_cat`),
  KEY `fk_cat_cat_productos_productos_idx` (`id_producto`),
  KEY `fk_cat_cat_productos_categorias_idx` (`id_categoría`),
  KEY `fk_cat_cat_productos_contenidos_idx` (`id_contenido`),
  CONSTRAINT `fk_cat_cat_productos_categorias` FOREIGN KEY (`id_categoría`) REFERENCES `cat_categorias` (`id`),
  CONSTRAINT `fk_cat_cat_productos_contenidos` FOREIGN KEY (`id_contenido`) REFERENCES `cnt_contenidos` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_cat_cat_productos_definicion` FOREIGN KEY (`id_cat`) REFERENCES `cat_definicion` (`id`),
  CONSTRAINT `fk_cat_cat_productos_productos` FOREIGN KEY (`id_producto`) REFERENCES `cat_productos` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='detalle de los productos que se pueden utilizar en un catálogo';


-- madre.cdx_campaigns definition

CREATE TABLE `cdx_campaigns` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_frontal` bigint(20) unsigned NOT NULL,
  `id_catalogo` bigint(20) unsigned DEFAULT NULL,
  `nombre` varchar(255) NOT NULL,
  `fecha_inicio` datetime DEFAULT NULL,
  `fecha_fin` datetime DEFAULT NULL,
  `fichero_consentimiento` varchar(255) DEFAULT NULL COMMENT 'PDF con los datos de consentimiento para que el cliente en el frontal firme',
  `imagen_adicional` set('S','N') NOT NULL DEFAULT 'N' COMMENT 'switch para solicitar o no una imagen adicional de validacion en el formulario, si es de imagen, no puede ser de premio directo',
  `texto_imagen_adicional` varchar(200) DEFAULT NULL COMMENT 'Etiqueta para mostrar en la imagen adicional',
  `premio_directo` set('0','1') NOT NULL DEFAULT '0' COMMENT 'switch para saber si los regalos son de premio directo o no. si es de premio directo, no puede ser la campaña de imagen',
  `ruta_directo` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT 'Si es una campaña de acceso directo, este sería la url. Esto lo debe tener el cuenta el frontal a la hora de buscar el cliente con el "Dominio", ya que también ha de buscar aquí por si la encuentra, porque entonces debe ser esta campaña directamente, no por el precódigo',
  `productos_genericos` set('0','1') NOT NULL DEFAULT '0' COMMENT 'Esta columna señala si la campaña acepta productos genéricos (1) o no (0)',
  `retraso_email_canje` int(11) NOT NULL DEFAULT 0 COMMENT 'Horas de retraso en el envío del email al canjear; 0 -> sin retraso',
  `ini_val_enlace_descarga` int(11) NOT NULL DEFAULT 0 COMMENT 'En horas, desde cuando es el enlace valido desde el envío del email; (Solo digitales) ; 0 -> sin expiración. Por ejemplo si este campo tiene 24, y he enviado el correo el día 11/01/2021 a las 12:36, el enlace solo es válido si lo clickear después del día 12 a las 12:36 ',
  `duracion_enlace_descarga` int(11) NOT NULL DEFAULT 0 COMMENT 'Duración del enlace de descarga del cupón; (Solo digitales) Horas desde recibidio el correo de confirmación; 0 -> sin expiración',
  `fin_deeplinks` datetime DEFAULT NULL COMMENT 'Independientemente de los datos de validez calculados de los deeplink (Ini_val_enlace_descarga y duracion_enlace_descarga) , un deelinkk de una campaña, no se puede abrir después de esta fecha.',
  `status` int(1) NOT NULL DEFAULT 1 COMMENT '0 --> no se puede entrar en esta campaña; 1 --> Activa',
  `modulo` set('CAT','CDX','XPR','CAM') DEFAULT 'CDX',
  `sms_max_desde_frontal` int(11) NOT NULL DEFAULT 99 COMMENT 'Máximo número de veces que un cliente, desde el frontal, puede pedir que se le envíe el canje por sms. si se pone cero es que no se puede enviar',
  `reintento_imagen` int(11) NOT NULL DEFAULT 99 COMMENT 'Máximo número de veces que un usuario en una campaña con imagen puede reintentar subirla y rechazarse desde el BO',
  `max_canjes` int(11) NOT NULL DEFAULT 0 COMMENT 'Máximo de canjes que se pueden realizar en la campaña',
  `filtro_provincias` set('S','N') NOT NULL DEFAULT 'N' COMMENT 'En el frontal debe pasar o no por un filtro de provincias que limita los centros o experiencias o lo que sea  que hay que sacar',
  `filtro_categorias` set('S','N') NOT NULL DEFAULT 'S' COMMENT 'En el frontal debe pasar o no por un filtro de categorías que limita los centros o experiencias o lo que sea  que hay que sacar',
  `precodigo_unico` varchar(100) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_cdx_campaigns_frontales` (`id_frontal`),
  KEY `fk_cdx_campaigns_catalogo_idx` (`id_catalogo`),
  CONSTRAINT `fk_cdx_campaigns_catalogo` FOREIGN KEY (`id_catalogo`) REFERENCES `cat_definicion` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_cdx_campaigns_frontales` FOREIGN KEY (`id_frontal`) REFERENCES `cdx_frontales` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cdx_campaigns_cnt_mensajes definition

CREATE TABLE `cdx_campaigns_cnt_mensajes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_campaign` bigint(20) unsigned NOT NULL,
  `id_contenido` bigint(20) unsigned NOT NULL,
  `tipo_mensaje` varchar(20) NOT NULL COMMENT 'codigo para que el programador sepa que tipo de contenido es: de bienvenida, premio Ok,...',
  `descripcion` varchar(200) NOT NULL COMMENT 'Texto para que el gestor sepa que tipo de contenido es: de bienvenida, premio Ok,...',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_CDX_campaigns_cnt_mensajes_campaigns_idx` (`id_campaign`),
  CONSTRAINT `FK_CDX_campaigns_cnt_mensajes_campaigns` FOREIGN KEY (`id_campaign`) REFERENCES `cdx_campaigns` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=62 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Esta tabla (tenemos que hablarlo) solo es de consulta ymodifiación no se pueden añadir registros por el BO, ya que es para programadores de Frontal. \nPara actualizar abrirá la opción de mantenimiento de contenidos (igual ya deberíamos crear un pantalla independiente para modificar contenidos)\n\nActualmente tenemos estos Tipo_mensajes:\n - bienvenida\n - premio_ok\n - pdte_validar\n - ok_validado\n - ko_validado\n';


-- madre.cdx_archivos definition

CREATE TABLE `cdx_archivos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_campaign` bigint(20) unsigned NOT NULL,
  `id_canje` bigint(20) unsigned NOT NULL,
  `ruta` varchar(255) NOT NULL,
  `nombre` varchar(255) NOT NULL COMMENT 'Guardar en el sistema con un nombre formateado: frontal + campaña + ¿precodigo? + nombre.ext',
  `tipo` set('1','2','3','4','5') NOT NULL COMMENT '1 —> DNI delantera; 2 —-> DNI Trasera;  3 —>Consentimiento;  4 —>comprobantes;  5 ->Ficheros adicionales',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_cdx_archivos_campaigns_idx` (`id_campaign`),
  KEY `fk_cdx_archivos_canje_idx` (`id_canje`),
  CONSTRAINT `fk_cdx_archivos_campaigns` FOREIGN KEY (`id_campaign`) REFERENCES `cdx_campaigns` (`id`),
  CONSTRAINT `fk_cdx_archivos_canje` FOREIGN KEY (`id_canje`) REFERENCES `cnj_canjes` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=250 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cdx_precodigos definition

CREATE TABLE `cdx_precodigos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `precodigo` varchar(50) NOT NULL,
  `id_canje` bigint(20) unsigned DEFAULT NULL,
  `id_frontal` bigint(20) unsigned NOT NULL,
  `id_campaign` bigint(20) unsigned DEFAULT NULL,
  `id_participante` bigint(20) unsigned DEFAULT NULL,
  `premiado` int(11) NOT NULL DEFAULT 1 COMMENT '0 --> No premiado, es decir, cuando entre en el frontal se le sacará un mensaje de que no puede acceder; 1 --> Premiado, puede entrar al catálogo',
  `status` set('0','1','2','3') DEFAULT '0' COMMENT '0 --> sin enviar (ya sea a un fichero o por emal/sms); 1 --> Activo (se ha enviado); 2 --> Inactivo (se ha anulado, pero siempre antes de canjear); 3 --> para que, en campañas con precódigos únicos, solo coja estatus 3 y los ponga a 0 cuando los seleccione con el precódigo único',
  `fichero` varchar(255) DEFAULT NULL COMMENT 'fichero en el que se suben los precodigos clientes y se ha creado el precodigo',
  `fichero_tipo` varchar(45) DEFAULT NULL,
  `observaciones` varchar(4000) DEFAULT NULL,
  `caducidad` timestamp NULL DEFAULT NULL COMMENT 'Fecha de caducidad del código, no puede ser superior a la de la campaña, si es nula es que no tiene y por lo tanto tiene la caducidad que tenga la campaña',
  `fake` set('0','1') DEFAULT '0' COMMENT '0 --> no es Fake; 1 --> es Fake. Los códigos Fake, llevan el prefijo "FAKE_" + Lo indicado en la carga',
  `envios_id` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`envios_id`)),
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `fk_cdx_precodigos_precodigo` (`precodigo`),
  KEY `fk_cdx_precodigos_canje_idx` (`id_canje`),
  KEY `fk_cdx_precodigos_campaign_idx` (`id_campaign`),
  KEY `fk_cdx_precodigos_hxxi_participantes` (`id_participante`),
  KEY `fk_cdx_precodigos_frontales` (`id_frontal`),
  CONSTRAINT `fk_cdx_precodigos_campaign` FOREIGN KEY (`id_campaign`) REFERENCES `cdx_campaigns` (`id`),
  CONSTRAINT `fk_cdx_precodigos_canje` FOREIGN KEY (`id_canje`) REFERENCES `cnj_canjes` (`id`),
  CONSTRAINT `fk_cdx_precodigos_frontales` FOREIGN KEY (`id_frontal`) REFERENCES `cdx_frontales` (`id`),
  CONSTRAINT `fk_cdx_precodigos_hxxi_participantes` FOREIGN KEY (`id_participante`) REFERENCES `hxxi_participantes` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=21151 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cnj_campos definition

CREATE TABLE `cnj_campos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_canje` bigint(20) unsigned NOT NULL,
  `modulo` set('CAT','CDX','XPR') NOT NULL COMMENT 'Modulo al que pertenece id_campos',
  `id_campo` bigint(20) unsigned NOT NULL COMMENT 'dependerá del campo "modulo"',
  `valor` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_cnj_campos_canjes_idx` (`id_canje`),
  CONSTRAINT `fk_cnj_campos_canjes` FOREIGN KEY (`id_canje`) REFERENCES `cnj_canjes` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=338 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cnj_canjes definition

CREATE TABLE `cnj_canjes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `id_participante` bigint(20) unsigned NOT NULL,
  `id_cat` bigint(20) unsigned DEFAULT NULL COMMENT 'aunque lo podemos sacar por el producto',
  `id_producto` bigint(20) unsigned DEFAULT NULL COMMENT 'id del producto de cat_cat_producto. Puede ser nulo porque en el caso de canje de semillas el valor que debe llevar es el de id_semilla',
  `id_semilla` bigint(20) unsigned DEFAULT NULL COMMENT 'Relacionado con la tabla de semillas exp_experiencias. Puede ser nulo porque en el caso de canje no de semillas el valor que debe llevar es el de id_producto',
  `id_campaign` bigint(20) unsigned DEFAULT NULL COMMENT 'Id de campaña si el canje se ha realizado por (CODEX) si no es nulo',
  `unidades` int(10) unsigned NOT NULL DEFAULT 1 COMMENT 'cantidad de producctos vendidos en este canje',
  `puntos` decimal(8,2) unsigned NOT NULL COMMENT 'puntos unitarios supone el canje, debe corresponderse con el movimiento generado',
  `estado` set('1','2','3','4','5') NOT NULL DEFAULT '1' COMMENT '1--> Realizado: El participante ha hecho el pedido y hay que enviarlo, no tiene confirmación.\\n2--> Pendiente confirmar: El cliente ha hecho el pedido, pero es un pedido pendiente de confirmación.   \\n3--> Confirmado: El cliente ha hecho un pedido que necesita confirmación y un gestor lo ha confirmado.   \\n4--> Rechazado: El cliente ha hecho el pedido que necesita confirmación y un gestor lo ha anulado (aunque podría ser un proceso el que lo ha rechazado).   \\n5-->Anulado: Un pedido ya creado se ha anulado (por el motivo que sea).   \\\\n6--> Enviado: en pedidos realizados o confirmados. El pedido se ha enviado. En los digitales es cuando se envía el email o sms, en los físicos es cuando se descarga el fichero para el proveedor logístico.',
  `modulo` set('CAT','CDX','XPR','CAM') DEFAULT 'CAT',
  `fec_canje` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Fecha en la que se realiza el canje. Estado 1',
  `fec_aprobado` timestamp NULL DEFAULT NULL COMMENT 'Fecha en la que se aprueba un canje que lleva aprobación. Si no es de aprobación coinciede con la fecha de canje. Genera el movimiento id_mov_canje. Estado 3',
  `fec_rechazado` timestamp NULL DEFAULT NULL COMMENT 'Fecha en la que se rechaza en una aprobación. Estado 4',
  `fec_anulado` timestamp NULL DEFAULT NULL COMMENT 'Fecha en la que se anula (no es por sistema de aprobaciones). Genera el movimiento de anulación id_mov_anula. Estado 5',
  `fec_enviado` timestamp NULL DEFAULT NULL COMMENT 'Fecha en la que se ha enviado el canje. Estado 6',
  `id_mov_canje` bigint(20) unsigned DEFAULT NULL COMMENT 'ID del movimiento de canje generado',
  `id_mov_anula` bigint(20) unsigned DEFAULT NULL COMMENT 'ID del movimiento de anulación generado si el canje se h anulado',
  `links_vouchers` varchar(4000) DEFAULT NULL COMMENT 'Estructura (json): ‘[{\\\\"link\\\\":\\\\"https:\\\\\\\\/\\\\\\\\/gentestcore.helloyalty.cloud\\\\\\\\/download-voucher\\\\\\\\/2d8da74857d183ea59a5\\\\",\\\\"inicio_validez_cupon\\\\":\\\\"2022-05-12T18:34:16+02:00\\\\",\\\\"fin_validez_cupon\\\\":null,\\\\"valor\\\\":\\\\"10.00\\\\"}]’  con todos los links de todos los vouchers que tiene este canje, normalmente será uno, pero podrían ser varios',
  `nombre` varchar(50) DEFAULT NULL,
  `email` varchar(255) NOT NULL,
  `telf` varchar(15) DEFAULT NULL,
  `id_direccion` bigint(20) unsigned DEFAULT NULL,
  `fiscal_nombre` varchar(50) DEFAULT NULL,
  `fiscal_apellidos` varchar(50) DEFAULT NULL,
  `fiscal_dni` varchar(20) DEFAULT NULL,
  `fiscal_telefono` varchar(20) DEFAULT NULL,
  `fiscal_id_direccion` bigint(20) unsigned DEFAULT NULL,
  `comentario` varchar(2000) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_cnj_canjes_hxxi_participante_idx` (`id_participante`),
  KEY `fk_cnj_canjes_cat_definicion_idx` (`id_cat`),
  KEY `fk_cnj_canjes_cat_cat_producto_idx` (`id_producto`),
  KEY `idx_cnj_canjes_campaign` (`id_campaign`),
  KEY `fk_cnj_canjes_exp_experencias_idx` (`id_semilla`),
  CONSTRAINT `fk_cnj_canjes_cat_cat_producto` FOREIGN KEY (`id_producto`) REFERENCES `cat_cat_productos` (`id`),
  CONSTRAINT `fk_cnj_canjes_cat_definicion` FOREIGN KEY (`id_cat`) REFERENCES `cat_definicion` (`id`),
  CONSTRAINT `fk_cnj_canjes_exp_experencias` FOREIGN KEY (`id_semilla`) REFERENCES `exp_experiencias` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_cnj_canjes_hxxi_participante` FOREIGN KEY (`id_participante`) REFERENCES `hxxi_participantes` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=347 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.cnj_ficheros definition

CREATE TABLE `cnj_ficheros` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_canje` bigint(20) unsigned NOT NULL,
  `modulo` set('CAT','CDX','XPR') NOT NULL COMMENT 'Modulo al que pertenece id_campos',
  `localizacion` varchar(500) NOT NULL,
  `fichero` varchar(100) NOT NULL,
  `extension` varchar(5) NOT NULL COMMENT 'PDF, DOC, JPG.....',
  `tipo` set('DNI1','DNI2','CONS','TICKET','OTRO') NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_cnj_ficheros_idx` (`id_canje`),
  CONSTRAINT `fk_cnj_ficheros` FOREIGN KEY (`id_canje`) REFERENCES `cnj_canjes` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=175 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.exp_centros definition

CREATE TABLE `exp_centros` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_centro` bigint(20) unsigned NOT NULL COMMENT 'Relacionado con la tabla de hxxi_centros',
  `id_contenido` bigint(20) unsigned NOT NULL COMMENT 'el contenido es un ID directo al mismo, pero para cuando se crea el contenido debe ser con el ID_APP que se indica en la tabla de hxxi_canfiguracion para la aplicación=0 (superadministrador) y con nombre id_app_semillas.',
  `id_provincia` bigint(20) unsigned NOT NULL,
  `estado` set('0','1') NOT NULL DEFAULT '0' COMMENT '0 --> Inactiva; 1--> Activa',
  `desde` timestamp NOT NULL DEFAULT current_timestamp(),
  `hasta` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_exp_centros_hxxi_centros_idx` (`id_centro`),
  KEY `FK_exp_centros_dir_provincias_idx` (`id_provincia`),
  CONSTRAINT `FK_exp_centros_dir_provincias` FOREIGN KEY (`id_provincia`) REFERENCES `dir_provincias` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `FK_exp_centros_hxxi_centros` FOREIGN KEY (`id_centro`) REFERENCES `hxxi_centros` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=161 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_centros definition

CREATE TABLE `hxxi_centros` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_empresa` bigint(20) unsigned NOT NULL COMMENT 'Centro_Empresa a la que pertenece',
  `nombre` varchar(255) NOT NULL,
  `estado` set('AC','IN','PE') NOT NULL DEFAULT 'IN' COMMENT 'Actica, Inactiva, pendiente de firma ',
  `fec_alta` date DEFAULT NULL,
  `fec_baja` datetime DEFAULT NULL,
  `contacto` varchar(100) DEFAULT NULL,
  `telefono` varchar(15) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `id_dir_comercial` bigint(20) unsigned DEFAULT NULL,
  `Nombra_fiscal` varchar(255) DEFAULT NULL,
  `Doc_fiscal` varchar(15) DEFAULT NULL,
  `id_dir_fiscal` bigint(20) unsigned DEFAULT NULL,
  `orden_pago_fec_hasta` date DEFAULT NULL,
  `orden_pago_fichero` varchar(255) DEFAULT NULL,
  `estado_pago` set('LI','PE','PA','RE') NOT NULL DEFAULT 'LI' COMMENT 'Libre --> no tiene compromiso de pago porque se paga por otra via, promoción o lo que sea\nPendiente --> Se ha emitido la factura y no se ha pagado todavía\nPagado --> Se ha pagado la última orden\nRetraso --> Está retrasado en el pago',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_hxxi_centros_dir_comercial_idx` (`id_dir_comercial`),
  KEY `fk_hxxi_centros_dir_fiscal_idx` (`id_dir_fiscal`),
  KEY `fk_hxxi_centros_centros_empresa_idx` (`id_empresa`),
  CONSTRAINT `fk_hxxi_centros_centros_empresa` FOREIGN KEY (`id_empresa`) REFERENCES `hxxi_empresas` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_hxxi_centros_dir_comercial` FOREIGN KEY (`id_dir_comercial`) REFERENCES `dir_direcciones` (`id`),
  CONSTRAINT `fk_hxxi_centros_dir_fiscal` FOREIGN KEY (`id_dir_fiscal`) REFERENCES `dir_direcciones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=162 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_empresas definition

CREATE TABLE `hxxi_empresas` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_centro_principal` bigint(20) unsigned DEFAULT NULL COMMENT 'Centro que va a dar los datos fiscales, etc a la empresa.. Puede ser nulo, porque al crearla nueva no tengo porqué tener centros',
  `nombre` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_hxxi_centros_empresa_centros_idx` (`id_centro_principal`),
  CONSTRAINT `fk_hxxi_centros_empresa_centros` FOREIGN KEY (`id_centro_principal`) REFERENCES `hxxi_centros` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=158 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_participantes definition

CREATE TABLE `hxxi_participantes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `id_centro` bigint(20) unsigned DEFAULT NULL,
  `nombre` varchar(40) DEFAULT NULL,
  `apellidos` varchar(60) DEFAULT 'Apellido',
  `email` varchar(255) DEFAULT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `username` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `remember_token` varchar(100) DEFAULT NULL,
  `fec_nacimiento` date DEFAULT NULL,
  `telefono` varchar(15) DEFAULT NULL,
  `direccion` varchar(255) DEFAULT NULL,
  `zipcode` varchar(15) DEFAULT NULL,
  `provincia` varchar(100) DEFAULT NULL,
  `pais` varchar(100) DEFAULT NULL,
  `fiscal_doc` varchar(10) DEFAULT NULL,
  `fiscal_nombre` varchar(100) DEFAULT NULL,
  `status` tinyint(1) DEFAULT 0 COMMENT '1 --> habilitado; 0 --> inhabilitado',
  `id_externo` varchar(20) DEFAULT NULL COMMENT 'ID del frontal o servicio externo que está tratando la apliación, si lo hubiera',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  `_lft` int(10) unsigned DEFAULT 0,
  `_rgt` int(10) unsigned DEFAULT 0,
  `parent_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_hxxi_participantes_aplicaciones` (`id_app`),
  KEY `fk_hxxi_participantes_centros_idx` (`id_centro`),
  CONSTRAINT `fk_hxxi_participantes_aplicaciones` FOREIGN KEY (`id_app`) REFERENCES `hxxi_aplicaciones` (`id`),
  CONSTRAINT `fk_hxxi_participantes_centros` FOREIGN KEY (`id_centro`) REFERENCES `hxxi_centros` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=513 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.hxxi_participantes_totales definition

CREATE TABLE `hxxi_participantes_totales` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_participante` bigint(20) unsigned NOT NULL,
  `saldo` decimal(11,2) DEFAULT 0.00,
  `utilizado` decimal(11,2) DEFAULT 0.00,
  `caducado` decimal(11,2) DEFAULT 0.00,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_hxxi_participantes_totales` (`id_participante`),
  CONSTRAINT `fk_hxxi_participantes_totales` FOREIGN KEY (`id_participante`) REFERENCES `hxxi_participantes` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=114 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- madre.mov_movimientos definition

CREATE TABLE `mov_movimientos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `id_app` bigint(20) unsigned NOT NULL,
  `id_participante` bigint(20) unsigned NOT NULL,
  `id_centro` bigint(20) unsigned DEFAULT NULL,
  `id_mov` bigint(20) unsigned DEFAULT NULL,
  `fecha` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `id_concepto` bigint(20) unsigned NOT NULL,
  `descripcion` varchar(250) DEFAULT NULL,
  `puntos` decimal(11,2) DEFAULT 0.00 COMMENT ' Recordar que  Importe debe ser igual a caducado + anulado + utilizado.',
  `anulado` decimal(11,2) DEFAULT 0.00 COMMENT 'Importe anulado de la operación Recordar que  Importe debe ser igual a caducado + anulado + utilizado.',
  `utilizado` decimal(11,2) DEFAULT 0.00 COMMENT 'Importe que se ha utilizado en los canjes. Recordar que  Importe debe ser igual a caducado + anulado + utilizado.',
  `caducado` decimal(11,2) DEFAULT 0.00 COMMENT 'Importe que se ha caducado a esta operación. Una vez caducada el Importe debe ser igual a caducado + anulado + utilizado y ya es inamovible',
  `saldo` decimal(11,2) DEFAULT NULL COMMENT 'Saldo acumulado a partir de esta operación. No es válido para todas las IpAPP',
  `fec_caducidad` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT 'FEcha en la que está operación podría caducar su saldo restante',
  `fichero` varchar(250) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL,
  `modified_by` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_mov_movimientos_hxxi_participantes` (`id_participante`),
  KEY `fk_mov_movimientos_hxxi_centros_idx` (`id_centro`),
  KEY `fk_mov_movimientos_conceptos_idx` (`id_concepto`),
  CONSTRAINT `fk_mov_movimientos_conceptos` FOREIGN KEY (`id_concepto`) REFERENCES `mov_conceptos` (`id`),
  CONSTRAINT `fk_mov_movimientos_hxxi_centros` FOREIGN KEY (`id_centro`) REFERENCES `hxxi_centros` (`id`),
  CONSTRAINT `fk_mov_movimientos_hxxi_participantes` FOREIGN KEY (`id_participante`) REFERENCES `hxxi_participantes` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1805096 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;