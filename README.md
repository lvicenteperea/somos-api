# Parking API

API para la gestión de aparcamientos y partners utilizando FastAPI y SQLModel.

## Estructura del proyecto

```
app/
├── __init__.py
├── database.py
├── main.py
├── models/
│   ├── __init__.py
│   └── apk_partner.py
└── routes/
    ├── __init__.py
    └── apk_partner.py
```

## Configuración

1. Instalar dependencias:

```bash
pip install fastapi sqlmodel uvicorn pymysql
```

2. Configurar la conexión a la base de datos en `app/database.py`:

```python
DATABASE_URL = "mysql+pymysql://user:password@localhost:3306/parking_db"
```

## Ejecución

Para iniciar el servidor:

```bash
uvicorn app.main:app --reload
```

La API estará disponible en `http://localhost:8000`

## Documentación

La documentación automática de la API está disponible en:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Endpoints principales

- `GET /apk-partners/`: Listar todos los registros de partners con aparcamientos
- `POST /apk-partners/`: Crear un nuevo registro
- `GET /apk-partners/{partner_id}`: Obtener un registro por ID
- `PATCH /apk-partners/{partner_id}`: Actualizar un registro
- `DELETE /apk-partners/{partner_id}`: Eliminar un registro
- `GET /apk-partners/partner/{id_partner}/parking/{parking}`: Buscar por ID de partner y código de parking




   - "ERR_PARAMETROS", Error en la llegada de parámetros, es un error interno, solo se debería de dar en DEV
   - "ERR_INTERNO", Error que se ha salido por una excepción genérica
   - "LOG_ABN_FREQ_NO_COINCIDE", No coincide este abono (XXX) con frecuencia: YYY con la frecuencia recibida: ZZZ
   - "LOG_ABN_NO_CANCELABLE", Este abono no se encuentra en un estado que se pueda cancelar (XXX)
   - "LOG_ABN_NO_CANCELABLE", Este producto no se puede cancelar (XXX)
   - "LOG_ABN_NO_COINCIDE", No coincide este abono (XXX) con producto: YYY con el producto recibido: ZZZ
   - "LOG_ABN_NO_EXISTE", No Existe el abono indicado.
   - "LOG_ABN_NO_SEDE", Este abono (XXX) no está asociado a ninguna sede
   - "LOG_ABN_PARA_PARTNER", No existe el parking XXX asociado al partner YYY
   - "LOG_ABN_SIN_PLAZAS", No hay plazas suficientes en el aparcmiento: XXXX y mes YY -> Plazas ocupadas: ZZ. Plazas pedidas: QQ. Plazas Máximas: 99
   - "LOG_ABN_SIN_VALORES", No existe precio para este abono: ZZZ - YYY
   - "LOG_ABN_ERROR", No existe precio para este abono: ZZZ - YYY
   - "LOG_APK_NO_EXISTE", El aparcamiento ZZZ no existe para el Sistema de Control YY
   - "LOG_APK_RESTRICCIONES", El aparcamiento ZZZ tiene restricciones horarias propias (YYY)
   - "LOG_CLI_DOC_EXISTE", Ya existe una cuenta con ese documento: XXXXXXXXX
   - "LOG_CLI_EMAIL_OBL", El email es obligatorio
   - "LOG_CLI_INEXISTENTE", El cliente XXX No existe o está dado de baja
   - "LOG_CLI_NO_EXISTE", El cliente XXXX No existe o está dado de baja
   - "LOG_CLI_NO_MAT", El cliente XXX No tiene el vehículo: XXXXX
   - "LOG_CLI_NO_METODO_PAGO", El cliente no tiene un método de pago valido
   - "LOG_CLI_NO_TJT", El cliente XXX No tiene tarjetas activas
   - "LOG_CLI_NOMBRE_ERR", El nombre XXX es erróneo
   - "LOG_CLI_SIN_VEH", El cliente XXX No tiene el vehículo: XXXX
   - "LOG_CLIENTE_FUERA", Cliente de Clubö con el vehículo XXXX ya ha salido del aparcamiento XXXXXXXX
   - "LOG_DIR_INEXISTENTE", La dirección indicada no existe
   - "LOG_DIR_YA_ASOCIADA", La dirección indicada ya está asociada a un cliente u otra entidad
   - "LOG_EMAIL_YA_EXISTE", Ya existe una cuenta con ese email en usuarios: XXXX@XXXX.com;
   - "LOG_FDESDE_MAYOR_ACTUAL", La fecha de este ID ya ha pasado, no se puede cancelar
   - "LOG_FEC_ABONO_FEC_INI", En una fecha de inico de abono, anterior al mes de inicio de abono, no puede ser de un mes diferente al anterior de inicio del abono
   - "LOG_FEC_ABONO_ANTERIOR_ACT", No se pueden hacer abonos de este mes o anteriores: yyyy-mm-dd - yyyy-mm-dd
   - "LOG_FECHAS_MENOR_ACTUAL", Las fechas deben ser futuras: XXXXX - yyyy-mm-dd  - yyyy-mm-dd
   - "LOG_FORMATO_FECHA", La fecha debe tener formato: aaaa-mm-dd hh:mi:ss
   - "LOG_INTERNO", El ID de tarjeta es obligatorio
   - "LOG_MAT_ANONIMA", La matricula XXXX No es cliente de ningún partner XXXX - dd-mm-aaaa;
   - "LOG_MAT_LISTA_NEGRA", La matricula XXXX está en la lista negra para el aparcamiento XXXX;
   - "LOG_MAT_NO_ABONO", Matricula con estado Baja y no es cliente de Abono
   - "LOG_MAT_NO_CLIENTE", No se encuentra la matrícula XXXX para el cliente XXXXXX
   - "LOG_MAT_SIN_PERMISOS", Esta matrícula XXXX no tiene perimsos para entrar en el aparcamiento
   - "LOG_MATRICULA_OBL", Es obligatorio recibir una matricula
   - "LOG_NO_CANAL", El Canal es obligatorio
   - "LOG_NO_CANAL_BOOKING", El Canal Booking Code es obligatorio
   - "LOG_NO_COINCIDEN_APK", No coincide el parking de la solicitud de precio (XXXXX) con el de la petición de reserva (XXXXX)
   - "LOG_NO_COINCIDEN_FECHAS", Las fechas de la solicitud de precio (XXXXX - XXXXX) no coinciden con los de la petición de la reserva (XXXXX - XXXXX)
   - "LOG_NO_EXISTE_TIPO", No existe ningún tipo de producto de reservas prd_res_crea
   - "LOG_NO_HAY_PAGO", Si es de Clubö debe haber un pago
   - "LOG_NO_MES_PROD", No hay meses para este producto:XXXXX -XXXXX -XXXXX-XXXXX-XXXXX
   - "LOG_NO_PLAZAS_DISP", Las fechas de entrada/salida no son correctas: XXXXX - XXXXX
   - "LOG_NO_PROD_ACTIVO", No dispone de un producto activo para poder entrar
   - "LOG_NO_SE_ENCUENTRA_PARTNER", No se encuentra el partner (XXXXX)
   - "LOG_NO_TIPO_RESERVA", No existe ningún tipo de producto de reservas
   - "LOG_NOEXIST_APK_EN_PARTNER", No existe el parking XXXXX,  asociado al partner XXXXX 
   - "LOG_PARTNER_BAJA_NOEXISTE", El partner no existe o no está de baja XXXXX
   - "LOG_PARTNER_RESERVA", El Partner es de reserva por lo que debe estar en local XXXXX
   - "LOG_PROD_ABN_NO_EXISTE", El producto abono XXXXX No existe
   - "LOG_PROD_NO_PERMITE_ENTRADA_FECHA", El producto que tiene no permite la entrada en este rango de fecha/hora
   - "LOG_RES_ANTICIPADA", Esta reserva tiene un periodo de anticipación de XXXXX minutos
   - "LOG_RES_CANC_FUERA_FECHAS", No se encuentra en unas fechas en la que se pueda cancelar.
   - "LOG_RES_MIN_MINIMOS", El tiempo mínimo de reserva son XXXXX minutos
   - "LOG_RES_NO_CANCELABLE", Esta reserva no se encuentra en un estado que se pueda cancelar (XXXXX)
   - "LOG_RES_NO_EXISTE", No Existe la reserva indicada.
   - "LOG_RES_NO_VALIDA_MES", El producto XXXXX de tipo Reserva (XXXXX) No existe o no es activo en algún mes
   - "LOG_SDC_NO_EXISTE", El SDC XXXXX  no existe
   - "LOG_SIN_PROD_ACTIVO", No dispone de un producto activo para poder entrar
   - "LOG_SIN_RESERVA", Error interno del sistema
   - "LOG_SIN_RESERV_PARTNER", No existe el producto detalle reserva para partners (XXXXX) 
   - "LOG_TOKEN_NO_EXISTE", No existe el token para ese producto
   - "LOG_TOKEN_NO_VALIDO", Este token/precio ya no es válido
   - "LOG_TOKEN_USADO", Este token/precio ya se ha asignado a otro comprador: XXXXXXXX
   - "LOG_VEH_IN", El vehículo XXXX se encuentra dentro de un aparcamiento: XXXXXX
   - "LOG_VEH_NO_PARTNER", No se encuentra información del vehículo XXXXX en el aparcamiento XXXX
   - "LOG_VEH_YA_EXISTE", Se está intentando dar de alta una matricula que ya existe.
   - "LOG_VEH_NO_EXISTEN", No existe estos vehículos o estan de baja ya o dentro del aparcamiento.... depende de la situación pero es que no se encuentran los vehículos que se buscan
   - "LOG_VEH_OTRO_CLIENTE", La matrícula está dada de alta en otro cliente
   - "LOG_TARIFAS_KO", No se ha encontrado un precio para los datos proporcionados
   - "LOG_USUARIO_ERRONEO", Usuario no recoonocido para crear reservas
   - "LOG_NO_CENTRO", El centro v_acronimo_centro no existe
   - "LOG_CLIENTE_OBL", El cliente es obligatorio
   - "LOG_ERR_BAJA_VEHICULO", Error al borrar vehículo ({cliente_id}-{vehiculo_id}): {str(e)}
   - "LOG_ERR_BAJA_CLIENTE", Error al borrar al cliente cliente_id: {str(e)}
   - "LOG_ERR_ALTA_VEHICULO", Error al dar de alta vehículo data.to_json(): {str(e)}
   - "LOG_ERR_MOD_VEHICULO", Error al modificar vehículo ({vehiculo_id}-{hasta or "hasta"}-{situacion or "situación"}): {str(e)}
   - "LOG_FREQ_INEXISTENTE", Frecuencia inexistente v_frecuencia
   - "LOG_MDP_NODISPONIBLE", No tiene ningun medio de pago activo: v_id_cliente
   - "TEXTO_OK", Todo Ok






Iconos Básicos para Consola
✅ Estados y Resultados
    print("✅ Operación exitosa")
    print("❌ Error")
    print("⚠️  Advertencia")
    print("🔄 Procesando...")
    print("⏳ En espera")
    print("🚀 Iniciando")
    print("🎉 Completado")
    print("💾 Guardando...")
🔍 Procesos de Datos
    print("📊 Procesando datos...")
    print("📁 Leyendo archivo...")
    print("🔍 Buscando...")
    print("📤 Enviando...")
    print("📥 Recibiendo...")
    print("🔄 Sincronizando...")
🐛 Debug y Logs
    print("🐛 Debug:")
    print("🔧 Configurando...")
    print("📝 Log:")
    print("🎯 Punto de control")
    print("🔎 Inspeccionando...")
❌ Errores y Problemas
    print("💥 Error fatal!")
    print("🚫 Acceso denegado")
    print("❓ Valor desconocido")
    print("🔒 Recurso bloqueado")
    print("📛 Timeout")
    print("💀 Crash!")
🌐 Red y Conexiones
    print("🌐 Conectando a API...")
    print("📡 Enviando request...")
    print("📶 Conexión establecida")
    print("📵 Sin conexión")
    print("🔗 Conectando a BD...")

🔗 Webs para Encontrar Más Emojis
    Emojipedia - https://emojipedia.org/

    Base de datos completa de emojis con códigos
        CopyPasteCharacter - https://copypastecharacter.com/
        Unicode Table - https://unicode-table.com/en/

