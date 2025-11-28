
/****** Object:  StoredProcedure [dbo].[sp_GenerarFacturas_Completo]     ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   PROCEDURE [dbo].[sp_GenerarFacturas_Completo]
      @inFecha DATE,
      @inDiasVencimiento INT = 15,
      @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    -- 1. DECLARACIÓN DE VARIABLES
    DECLARE @fechaDeVencimiento DATE = DATEADD(DAY,@inDiasVencimiento,@inFecha);
    DECLARE @PeriodoFactura INT = YEAR(@inFecha) * 100 + MONTH(@inFecha);
    
    -- Tabla Variable para almacenar el consumo de agua por finca
    DECLARE @CalculoConsumo TABLE (
          NumeroFinca     VARCHAR(64) PRIMARY KEY
        , LecturaActual   DECIMAL(10, 2)
        , LecturaAnterior DECIMAL(10, 2)
        , ConsumoM3       DECIMAL(10, 2)
        , MontoConsumo    MONEY
    );
    
    -- 2. CÁLCULO DE CONSUMO DE AGUA (CC 1)
    
    WITH ConsumoActual
    AS
    (
        SELECT
              P.NumeroFinca
            , P.SaldoM3UltimaFactura AS LecturaAnterior
            , P.SaldoM3 AS LecturaActual
        FROM dbo.Propiedad AS P
        INNER JOIN dbo.CCPropiedad AS CCP
            ON (CCP.NumeroFinca = P.NumeroFinca)
        WHERE (CCP.idConceptoCobro = 1)
          AND (CCP.idTipoAsociacion = 1)
    )
    INSERT INTO @CalculoConsumo
        (NumeroFinca
        , LecturaActual
        , LecturaAnterior
        , ConsumoM3
        , MontoConsumo)
    SELECT
          CA.NumeroFinca
        , CA.LecturaActual
        , CA.LecturaAnterior
        , (CA.LecturaActual - CA.LecturaAnterior)
        , CASE
            WHEN ((CA.LecturaActual - CA.LecturaAnterior) <= 30)
                THEN CAST(5000.00 AS MONEY)
            ELSE CAST(5000.00 AS MONEY) + CAST(((CA.LecturaActual - CA.LecturaAnterior) - 30.0) * 1000.0 AS MONEY)
          END
    FROM ConsumoActual AS CA
    WHERE ((CA.LecturaActual - CA.LecturaAnterior) > 0.0);

    
    -- 3. INSERCIÓN DE FACTURAS (Lógica de filtro por día de registro: CORRECTA)
    
    INSERT INTO dbo.Factura
        (NumeroFinca
        , FechaGeneracion
        , FechaOperacion
        , FechaVencimiento
        , Detalle
        , Estado
        , TotalAPagarOriginal
        , TotalAPagarFinal)
    SELECT
          DISTINCT P.NumeroFinca
        , @inFecha AS FechaGeneracion
        , @inFecha AS FechaOperacion
        , @fechaDeVencimiento AS FechaVencimiento
        , 'Factura de periodo ' + CAST(YEAR(@inFecha) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(MONTH(@inFecha) AS VARCHAR(2)), 2) AS Detalle
        , 'Pendiente' AS Estado
        , CAST(0.0 AS MONEY) AS TotalAPagarOriginal
        , CAST(0.0 AS MONEY) AS TotalAPagarFinal
    FROM dbo.Propiedad AS P
        INNER JOIN dbo.CCPropiedad AS CCP
            ON (CCP.NumeroFinca = P.NumeroFinca)
                WHERE (CCP.idTipoAsociacion = 1)
                    AND (DAY(P.FechaRegistro)=DAY(@inFecha)) -- Filtro de día de registro
                    AND NOT EXISTS (SELECT 1 FROM dbo.Factura AS FCH
                WHERE FCH.NumeroFinca=P.NumeroFinca
                    AND MONTH(FCH.FechaGeneracion) = MONTH(@inFecha)
                    AND YEAR(FCH.FechaGeneracion) = YEAR(@inFecha));

    
    -- 4. INSERCIÓN DE DETALLE DE FACTURA (CORREGIDO: Agregando 'Descripcion' y su valor)
    
    -- 4a. Impuesto Propiedad (CC 3)
    INSERT INTO dbo.DetalleFactura
        (NumeroComprobante
        , idConceptoCobro
        , Monto
        , Descripcion) -- <<-- CORRECCIÓN
    SELECT
          F.NumeroComprobante
        , 3
        , CAST((P.ValorFiscal * CC.ValorPorcentual) / 12.0 AS MONEY)
        , 'Impuesto de Propiedad' -- <<-- Valor Descripción
    FROM dbo.Factura AS F
    INNER JOIN dbo.Propiedad AS P
        ON (F.NumeroFinca = P.NumeroFinca)
    INNER JOIN dbo.ConceptoCobro AS CC
        ON (CC.id = 3)
    INNER JOIN dbo.CCPropiedad AS CCP
        ON (CCP.NumeroFinca = F.NumeroFinca)
       AND (CCP.idConceptoCobro = 3)
    WHERE (CCP.idTipoAsociacion = 1)
      AND (F.FechaGeneracion = @inFecha);

    -- 4b. Recolección Basura (CC 4)
    INSERT INTO dbo.DetalleFactura
        (NumeroComprobante
        , idConceptoCobro
        , Monto
        , Descripcion) -- <<-- CORRECCIÓN
    SELECT
          F.NumeroComprobante
        , 4
        , CAST(CC.ValorFijo AS MONEY) +
        CASE
            WHEN (P.MetrosCuadrados > 400)
            THEN CAST(CEILING((P.MetrosCuadrados - 400.0) / 200.0) * 75.0 AS MONEY)
            ELSE CAST(0.0 AS MONEY)
        END
        , 'Recolección de Basura' -- <<-- Valor Descripción
    FROM dbo.Factura AS F
    INNER JOIN dbo.Propiedad AS P
        ON (F.NumeroFinca = P.NumeroFinca)
    INNER JOIN dbo.ConceptoCobro AS CC
        ON (CC.id = 4)
    INNER JOIN dbo.CCPropiedad AS CCP
        ON (CCP.NumeroFinca = F.NumeroFinca)
       AND (CCP.idConceptoCobro = 4)
    WHERE (CCP.idTipoAsociacion = 1)
      AND (F.FechaGeneracion = @inFecha);

    -- 4c. Mantenimiento Parques (CC 5)
    INSERT INTO dbo.DetalleFactura
        (NumeroComprobante
        , idConceptoCobro
        , Monto
        , Descripcion) -- <<-- CORRECCIÓN
    SELECT
          F.NumeroComprobante
        , 5
        , CAST(CC.ValorFijo / 12.0 AS MONEY)
        , 'Mantenimiento de Parques' -- <<-- Valor Descripción
    FROM dbo.Factura AS F
    INNER JOIN dbo.ConceptoCobro AS CC
        ON (CC.id = 5)
    INNER JOIN dbo.CCPropiedad AS CCP
        ON (CCP.NumeroFinca = F.NumeroFinca)
       AND (CCP.idConceptoCobro = 5)
    WHERE (CCP.idTipoAsociacion = 1)
      AND (F.FechaGeneracion = @inFecha);

    -- 4d. Consumo de Agua (CC 1)
    INSERT INTO dbo.DetalleFactura
        (NumeroComprobante
        , idConceptoCobro
        , Monto
        , Descripcion) -- <<-- CORRECCIÓN
    SELECT
          F.NumeroComprobante
        , 1
        , CConsumo.MontoConsumo
        , CONCAT('Consumo de Agua (', CConsumo.ConsumoM3, ' m3)') -- <<-- Valor Descripción
    FROM dbo.Factura AS F
    INNER JOIN @CalculoConsumo AS CConsumo
        ON (CConsumo.NumeroFinca = F.NumeroFinca)
    WHERE (F.FechaGeneracion = @inFecha);

    -- 4e. Patente Comercial (CC 2)
    INSERT INTO dbo.DetalleFactura
        (NumeroComprobante
        , idConceptoCobro
        , Monto
        , Descripcion) -- <<-- CORRECCIÓN
    SELECT
          F.NumeroComprobante
        , 2
        , CAST(CC.ValorFijo / 6.0 AS MONEY) -- ValorFijo (Semestral) dividido entre 6 meses.
        , 'Patente Comercial Mensual' -- <<-- Valor Descripción
    FROM dbo.Factura AS F
    INNER JOIN dbo.ConceptoCobro AS CC
        ON (CC.id = 2)
    INNER JOIN dbo.CCPropiedad AS CCP
        ON (CCP.NumeroFinca = F.NumeroFinca)
       AND (CCP.idConceptoCobro = 2)
    WHERE (CCP.idTipoAsociacion = 1)
      AND (F.FechaGeneracion = @inFecha);

    -- 4f. Reconexión de Agua (CC 7)
    INSERT INTO dbo.DetalleFactura
        (NumeroComprobante
        , idConceptoCobro
        , Monto
        , Descripcion) -- <<-- CORRECCIÓN
    SELECT
          F.NumeroComprobante
        , 7
        , CAST(CC.ValorFijo AS MONEY) -- Monto Fijo de Reconexión
        , 'Reconexión de Servicio de Agua' -- <<-- Valor Descripción
    FROM dbo.Factura AS F
    INNER JOIN dbo.ConceptoCobro AS CC
        ON (CC.id = 7)
    INNER JOIN dbo.CCPropiedad AS CCP
        ON (CCP.NumeroFinca = F.NumeroFinca)
       AND (CCP.idConceptoCobro = 7) -- Se aplica si la finca tiene asociado este concepto
    WHERE (CCP.idTipoAsociacion = 1)
      AND (F.FechaGeneracion = @inFecha);


    -- 5. ACTUALIZAR SALDOS Y TOTALES (Sin cambios, es correcto)
    
    -- Actualizar el saldo M3 de la propiedad para la próxima facturación
    UPDATE P
    SET SaldoM3UltimaFactura = CConsumo.LecturaActual
    FROM dbo.Propiedad AS P
    INNER JOIN @CalculoConsumo AS CConsumo
        ON (P.NumeroFinca = CConsumo.NumeroFinca);

    -- Actualizar el Monto total en la Factura principal (TotalAPagarOriginal y TotalAPagarFinal inicial)
    -- Se suma el total de todos los conceptos (1, 2, 3, 4, 5, 7)
    UPDATE F
    SET TotalAPagarOriginal = ROUND(DF.MontoAcumulado, 2)
        , TotalAPagarFinal = ROUND(DF.MontoAcumulado, 2)
    FROM dbo.Factura AS F
    INNER JOIN 
        (
            SELECT 
                  DFi.NumeroComprobante
                , SUM(DFi.Monto) AS MontoAcumulado
            FROM dbo.DetalleFactura AS DFi
            INNER JOIN dbo.Factura AS F_INNER 
                ON (F_INNER.NumeroComprobante = DFi.NumeroComprobante)
               AND (F_INNER.FechaGeneracion = @inFecha)
            GROUP BY DFi.NumeroComprobante
        ) AS DF
        ON (F.NumeroComprobante = DF.NumeroComprobante)
    WHERE (F.FechaGeneracion = @inFecha);


    -- 6. APLICAR INTERESES MORATORIOS (Sin cambios, es correcto)
    
    -- Insertar el detalle de intereses moratorios para facturas pendientes y vencidas
    INSERT INTO dbo.DetalleFactura
        (NumeroComprobante
        , idConceptoCobro
        , Monto)
    SELECT
          F.NumeroComprobante
        , 6 -- ID asumido para Intereses Moratorios
        , CAST(F.TotalAPagarOriginal * (0.04 / 30.0) * DATEDIFF(DAY, F.FechaVencimiento, @inFecha) AS MONEY) AS MontoInteres
    FROM dbo.Factura AS F
    WHERE (F.Estado = 'Pendiente')
      AND (F.FechaVencimiento < @inFecha);

    UPDATE F
    SET TotalAPagarFinal = ROUND(DF.MontoAcumulado, 2)
    FROM dbo.Factura AS F
    INNER JOIN 
        (
            SELECT 
                  DFi.NumeroComprobante
                , SUM(DFi.Monto) AS MontoAcumulado
            FROM dbo.DetalleFactura AS DFi
            GROUP BY DFi.NumeroComprobante
        ) AS DF
        ON (F.NumeroComprobante = DF.NumeroComprobante)
    WHERE (F.Estado = 'Pendiente');


    RETURN 0;
END
