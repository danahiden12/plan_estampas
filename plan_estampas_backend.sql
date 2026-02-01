/* =====================================================
   BLOQUE 0 — CONTEXTO
   Tabla consolidada de plan de estampas
   Origen: Excel I26 + V26
   Uso: análisis de tiempos de proceso y eficiencia
   ===================================================== */

/* =====================================================
   BLOQUE 1 — ESTRUCTURA BASE
   Definición de la tabla final
   ===================================================== */

create table PLAN_ESTAMPAS (
    COLECCION NVARCHAR(50),
    ARTICULO NVARCHAR(50),
    DESCRIPCION NVARCHAR(MAX),                        -- aca los datos tuve que cargarlos como NVARCHAR
    COLOR NVARCHAR(50),                               -- porque me devolvia error datos tipo DATE o NUMERIC
    CANTIDAD NVARCHAR(50),
    EN_ORDENES NVARCHAR(50),
    EN_UNIDADES NVARCHAR(50),
    ESTAMPERIA NVARCHAR (50),
    FL_MAPA NVARCHAR(50),
    FL_CORTE NVARCHAR(50),
    FPC NVARCHAR(50),
    COSTO NVARCHAR(50),
    COSTO_8 NVARCHAR(50),
    MUESTRA_ENVIADA NVARCHAR(50),
    MUESTRA_RECIBIDA NVARCHAR (50),
    TIEMPO NVARCHAR(50),
    APROBADO NVARCHAR(50),
    FECHA_APROBADO NVARCHAR(50),
    DIF_TIEMPO_APROBADO NVARCHAR(50),
    COMENTARIO NVARCHAR(MAX),
    _2DA_CORRECCION NVARCHAR(50),
    A_DESPACHO NVARCHAR(50)
    );

/* =====================================================
   BLOQUE 2 — CARGA / CONSOLIDACIÓN
   UNION ALL de temporadas
   ===================================================== */

insert into PLAN_ESTAMPAS
select
    COLECCION,
    ARTICULO,
    DESCRIPCION, 
    COLOR,
    CANTIDAD, 
    EN_ORDENES,
    EN_UNIDADES,
    ESTAMPERIA, 
    FL_MAPA,
    FL_CORTE,
    FPC,
    COSTO,
    COSTO_8,
    MUESTRA_ENVIADA,
    MUESTRA_RECIBIDA,
    TIEMPO,
    APROBADO,
    FECHA_APROBADO,
    DIF_TIEMPO_APROBADO,
    COMENTARIO,
    _2DA_CORRECCION,
    A_DESPACHO

from PLAN_ESTAMPAS_I26

UNION ALL

select
    COLECCION,
    ARTICULO,
    DESCRIPCION, 
    COLOR,
    CANTIDAD, 
    EN_ORDENES,
    EN_UNIDADES,
    ESTAMPERIA, 
    FL_MAPA,
    FL_CORTE,
    FPC,
    COSTO,
    COSTO_8,
    MUESTRA_ENVIADA,
    MUESTRA_RECIBIDA,
    TIEMPO,
    APROBADO,
    FECHA_APROBADO,
    DIF_TIEMPO_APROBADO,
    COMENTARIO,
    _2DA_CORRECCION,
    A_DESPACHO
from PLAN_ESTAMPAS_V26;


/* =====================================================
   BLOQUE 3 — LIMPIEZA / NORMALIZACIÓN
   creacion de view: VW_PLAN_ESTAMPAS_LIMPIA
   ===================================================== */

CREATE OR ALTER VIEW VW_PLAN_ESTAMPAS_LIMPIA AS
SELECT
    COLECCION,
    ARTICULO,
    DESCRIPCION,
    COLOR,
    NULLIF(ESTAMPERIA, '#N/A') AS ESTAMPERIA,                                 -- Proveedores
    TRY_CONVERT(date, NULLIF(MUESTRA_ENVIADA, '#N/A'))  AS MUESTRA_ENVIADA,   -- Posibles formatos inválidos desde Excel (ver análisis BLOQUE 6)
    TRY_CONVERT(date, NULLIF(MUESTRA_RECIBIDA, '#N/A')) AS MUESTRA_RECIBIDA,  -- Posibles formatos inválidos desde Excel (ver análisis BLOQUE 6)
    TRY_CONVERT(date, NULLIF(FECHA_APROBADO, '#N/A'))   AS FECHA_APROBADO,    -- Posibles formatos inválidos desde Excel (ver análisis BLOQUE 6)
    NULLIF(APROBADO, '#N/A') AS APROBADO,                                     -- Estado muestrario
    NULLIF(A_DESPACHO, '#N/A') AS A_DESPACHO,                                 -- Estado muestrario
    TRY_CONVERT(int, NULLIF(CANTIDAD, '#N/A')) AS CANTIDAD                    -- Cantidad total por articulo

FROM PLAN_ESTAMPAS;
GO

/* =====================================================
   BLOQUE 4 — CALCULO DE TIEMPO DE PROCESOS
   creacion de view: VW_PLAN_ESTAMPAS_TIEMPOS
   ===================================================== */

CREATE OR ALTER VIEW VW_PLAN_ESTAMPAS_TIEMPOS AS
SELECT
    *,
    CASE 
        WHEN MUESTRA_ENVIADA IS NOT NULL 
        AND MUESTRA_RECIBIDA IS NOT NULL
        THEN DATEDIFF(DAY, MUESTRA_ENVIADA, MUESTRA_RECIBIDA)
        ELSE NULL
    END AS DIAS_ENVIO_MUESTRA,

    CASE
        WHEN APROBADO = 'SI'
        AND MUESTRA_RECIBIDA IS NOT NULL
        AND FECHA_APROBADO IS NOT NULL
        THEN DATEDIFF(DAY, MUESTRA_RECIBIDA, FECHA_APROBADO)
        ELSE NULL
    END AS DIAS_APROBACION

FROM VW_PLAN_ESTAMPAS_LIMPIA;
GO

/* =====================================================
   BLOQUE 5  — KPIS / AGREGACIONES 
   creacion de view: VW_ESTAMPAS_KPI_PROVEEDOR
   ===================================================== */

   CREATE OR ALTER VIEW VW_ESTAMPAS_KPI_PROVEEDOR  AS
SELECT
    ESTAMPERIA,
    COUNT(DISTINCT ARTICULO) AS CANT_ARTICULOS,
    COUNT(*) AS REGISTROS_TOTALES,
    SUM(CASE WHEN APROBADO = 'SI' THEN 1 ELSE 0 END) AS CANT_APROBADOS,
    AVG(DIAS_ENVIO_MUESTRA) AS PROM_DIAS_ENVIO_MUESTRA,
    AVG(DIAS_APROBACION) AS PROM_DIAS_APROBACION
    
FROM VW_PLAN_ESTAMPAS_TIEMPOS
GROUP BY ESTAMPERIA;
GO


/* =====================================================
   BLOQUE 6 — VALIDACIONES 
   Chequeos de calidad del dato
   ===================================================== */

/*
   SELECT *
FROM VW_PLAN_ESTAMPAS_LIMPIA                -- Aca valide que hay fechas sin formato standard                         
WHERE MUESTRA_RECIBIDA IS  NULL             -- Devuelve valores null cuando en la tabla madre no los tiene.
AND FECHA_APROBADO IS NOT NULL;            

                                         
SELECT                                      -- Query de diagnostico en base a NULL's
    MUESTRA_RECIBIDA 
FROM PLAN_ESTAMPAS
WHERE MUESTRA_RECIBIDA IS NOT NULL
  AND TRY_CONVERT(date, MUESTRA_RECIBIDA) IS NULL;

  */


/* =====================================================
   BLOQUE 7 — VIEW FINAL DE CONSUMO
   creacion de view: VW_ESTAMPAS_FINAL
   Uso: Fuente principal para Qlik
   ===================================================== */

CREATE OR ALTER VIEW VW_ESTAMPAS_FINAL AS
SELECT
    COLECCION,
    ARTICULO,
    DESCRIPCION,
    COLOR,
    ESTAMPERIA,
    CANTIDAD,

    -- Estados
    APROBADO,
    A_DESPACHO,

    -- Fechas clave
    MUESTRA_ENVIADA,
    MUESTRA_RECIBIDA,
    FECHA_APROBADO,

    -- Métricas de proceso
    DIAS_ENVIO_MUESTRA,
    DIAS_APROBACION

FROM VW_PLAN_ESTAMPAS_TIEMPOS;

