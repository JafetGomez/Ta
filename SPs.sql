USE [Facturacion]
GO
/****** Object:  StoredProcedure [dbo].[SP_BuscarFacturaPendiente]    Script Date: 27/11/2025 16:05:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_BuscarFacturaPendiente]
    @inNumeroFinca VARCHAR(64)
  , @inTasaInteresMensual FLOAT = 0.04
  , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NumeroComprobante      INT;
    DECLARE @FechaVencimiento       DATE;
    DECLARE @TotalFacturaOriginal   FLOAT;
    DECLARE @Hoy                    DATE = CAST(GETDATE() AS DATE);
    DECLARE @InteresCCID            INT  = 7; 
    DECLARE @DiasMora               INT;
    DECLARE @InteresCalculado       FLOAT;
    DECLARE @NuevoTotalAPagarFinal  FLOAT;
    DECLARE @FacturaEncontrada      BIT  = 0;
    SET @outResultCode = 0; 

    SELECT TOP 1
          @NumeroComprobante      = T1.NumeroComprobante
        , @FechaVencimiento       = T1.FechaVencimiento
        , @TotalFacturaOriginal   = T1.TotalAPagarOriginal
        , @FacturaEncontrada      = 1
    FROM
        dbo.Factura AS T1
    WHERE
        ( T1.NumeroFinca = @inNumeroFinca )
        AND ( T1.Estado = 'Pendiente' )
    ORDER BY
        T1.FechaVencimiento ASC;

    IF ( @FacturaEncontrada = 1 )
        AND ( @Hoy > @FechaVencimiento )
    BEGIN
        SET @DiasMora = DATEDIFF(DAY, @FechaVencimiento, @Hoy);
        SET @InteresCalculado = ( ( @TotalFacturaOriginal * @inTasaInteresMensual ) / 30.0 ) * @DiasMora;
        SET @InteresCalculado = ROUND(@InteresCalculado, 2);

        BEGIN TRANSACTION;

        BEGIN TRY

            IF EXISTS ( SELECT 1 FROM dbo.DetalleFactura AS T1 WHERE ( T1.NumeroComprobante = @NumeroComprobante ) AND ( T1.idConceptoCobro = @InteresCCID ) )
            BEGIN
                UPDATE dbo.DetalleFactura
                SET
                      Monto = @InteresCalculado
                    , Descripcion = CONCAT('Intereses Moratorios (ACTUALIZADO: ', @DiasMora, ' días)')
                WHERE
                      ( NumeroComprobante = @NumeroComprobante )
                  AND ( idConceptoCobro = @InteresCCID );
            END
            ELSE
            BEGIN
                INSERT INTO dbo.DetalleFactura
                    (
                      NumeroComprobante
                    , idConceptoCobro
                    , Monto
                    , Descripcion
                    )
                VALUES
                    (
                      @NumeroComprobante
                    , @InteresCCID
                    , @InteresCalculado
                    , CONCAT('Intereses Moratorios (NUEVO: ', @DiasMora, ' días)')
                    );
            END

            SELECT @NuevoTotalAPagarFinal = SUM(T1.Monto)
            FROM dbo.DetalleFactura AS T1
            WHERE ( T1.NumeroComprobante = @NumeroComprobante );

            UPDATE dbo.Factura
            SET
                TotalAPagarFinal = @NuevoTotalAPagarFinal
            WHERE
                ( NumeroComprobante = @NumeroComprobante );

            COMMIT TRANSACTION;

        END TRY
        BEGIN CATCH

            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            INSERT INTO dbo.DBErrors
                (
                  UserName
                , ErrorNumber
                , ErrorState
                , ErrorSeverity
                , ErrorLine
                , ErrorProcedure
                , ErrorMessage
                , ErrorDateTime
                )
            VALUES
                (
                  SUSER_SNAME()
                , ERROR_NUMBER()
                , ERROR_STATE()
                , ERROR_SEVERITY()
                , ERROR_LINE()
                , ERROR_PROCEDURE()
                , ERROR_MESSAGE()
                , GETDATE()
                );

            SET @outResultCode = 50001; 
            RETURN;

        END CATCH
    END
    IF @FacturaEncontrada = 1
    BEGIN
        -- Devuelve la factura encontrada/actualizada
        SELECT
            T1.* -- Selecciona todos los campos de la factura (incluyendo TotalAPagarFinal)
        FROM
            dbo.Factura AS T1
        WHERE
            T1.NumeroComprobante = @NumeroComprobante;
    END
    ELSE
    BEGIN
        SELECT
            CAST(NULL AS INT) AS NumeroComprobante -- Define las columnas esperadas
        WHERE 1 = 0; -- Condición que garantiza 0 filas
    END

END
/****** Object:  StoredProcedure [dbo].[SP_BuscarFacturasPorTermino]    Script Date: 27/11/2025 16:05:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_BuscarFacturasPorTermino]
    @inSearchTerm   VARCHAR(64)
  , @outResultCode  INT OUTPUT 
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    DECLARE @FincasRelevantes TABLE
    (
        NumeroFinca VARCHAR(64) PRIMARY KEY
    );

    BEGIN TRY
        INSERT INTO @FincasRelevantes (NumeroFinca)
        SELECT
              T1.NumeroFinca
        FROM
              dbo.Propiedad AS T1
        WHERE
              (T1.NumeroFinca = @inSearchTerm)  

        UNION

        SELECT
              T1.NumeroFinca
        FROM
              dbo.Propiedad AS T1
            INNER JOIN dbo.PropiedadPersona AS PP
                ON T1.NumeroFinca = PP.NumeroFinca
        WHERE
              (PP.ValorDocumento = TRY_CAST(@inSearchTerm AS INT)); 


        SELECT
              F.NumeroComprobante
            , F.NumeroFinca
            , F.FechaGeneracion
            , F.FechaVencimiento
            , F.TotalAPagarFinal
            , F.Estado
            , F.Detalle
        FROM
              dbo.Factura AS F
            INNER JOIN @FincasRelevantes AS FR  
                ON F.NumeroFinca = FR.NumeroFinca
        ORDER BY
              F.NumeroFinca ASC
            , F.FechaGeneracion DESC;

    END TRY
    BEGIN CATCH
        SET @outResultCode = 50001; 

        INSERT INTO dbo.DBErrors (
              ErrorNumber
            , ErrorSeverity
            , ErrorState
            , ErrorProcedure
            , ErrorLine
            , ErrorMessage
        )
        VALUES (
              ERROR_NUMBER()
            , ERROR_SEVERITY()
            , ERROR_STATE()
            , ERROR_PROCEDURE()
            , ERROR_LINE()
            , ERROR_MESSAGE()
        );
        

    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[SP_BuscarPropiedad]    Script Date: 27/11/2025 16:05:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_BuscarPropiedad]
    @inSearchTerm VARCHAR(64)
  , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    SELECT TOP 1
          P.NumeroFinca
        , P.MetrosCuadrados
        , TUP.nombre        AS UsoPropiedad
        , P.ValorFiscal
        , P.SaldoM3
    FROM
        dbo.Propiedad AS P
        LEFT JOIN dbo.TipoUsoPropiedad AS TUP
            ON ( P.idTipoUsoPropiedad = TUP.id )
    WHERE
        ( P.NumeroFinca = @inSearchTerm )
        OR ( P.NumeroFinca IN (
            SELECT
                PP.NumeroFinca
            FROM
                dbo.PropiedadPersona AS PP
            WHERE
                ( PP.ValorDocumento = TRY_CAST(@inSearchTerm AS INT) )
        ) );
END
GO
/****** Object:  StoredProcedure [dbo].[SP_LoginAdmin]    Script Date: 27/11/2025 16:05:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_LoginAdmin]
    @inUsername VARCHAR(64)
  , @inPassword VARCHAR(64)
  , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    SELECT
          T1.id
        , T1.nombre
    FROM
        dbo.UsuarioAdmin AS T1
    WHERE
        ( T1.nombre = @inUsername )
        AND ( T1.password = @inPassword );
END
GO
USE [Facturacion]
GO
/****** Object:  StoredProcedure [dbo].[SP_ProcesarPago]    Script Date: 8/12/2025 20:43:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_ProcesarPago]
      @inNumeroComprobante       INT
    , @inNumeroFinca             VARCHAR(64)
    , @inMontoRecibido           NUMERIC(18,2)
    , @inIdTipoMedioPago         INT
    , @inFechaOperacion          DATE          -- NUEVO PARÁMETRO DE FECHA DEL XML
    , @outSuccess                BIT OUTPUT
    , @outMessage                NVARCHAR(255) OUTPUT
    , @outMontoFinalPagado       MONEY OUTPUT
    , @outCodigoComprobante      VARCHAR(64) OUTPUT
    , @outResultCode             INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- 0. INICIALIZACIÓN DE VARIABLES DE SALIDA
    SET @outSuccess             = 0;
    SET @outMontoFinalPagado    = 0;
    SET @outCodigoComprobante   = NULL;
    SET @outResultCode          = 0;

    -- 1. DECLARACIÓN DE VARIABLES INTERNAS
    DECLARE @MontoAPagar                 NUMERIC(18,2);
    DECLARE @EstadoActual                VARCHAR(64);
    -- SE ELIMINA LA DECLARACIÓN DE @Hoy = GETDATE()
    DECLARE @ComprobanteCode             VARCHAR(64);
    DECLARE @idOrdenCortePendiente       INT;

    -- 2. VALIDACIÓN DE FACTURA Y MONTO
    
    -- Obtener datos de la factura
    SELECT TOP 1
          @MontoAPagar    = T1.TotalAPagarFinal
        , @EstadoActual   = T1.Estado
    FROM dbo.Factura AS T1
    WHERE ( T1.NumeroComprobante = @inNumeroComprobante )
      AND ( T1.NumeroFinca = @inNumeroFinca );

    -- Validar existencia
    IF ( @MontoAPagar IS NULL )
    BEGIN
        SET @outMessage = N'Factura no encontrada o no pertenece a la finca.';
        SET @outResultCode = 50002;
        RETURN;
    END

    -- Validar estado
    IF ( @EstadoActual <> 'Pendiente' )
    BEGIN
        SET @outMessage = N'Factura ya está en estado: ' + @EstadoActual + '.';
        SET @outResultCode = 50003;
        RETURN;
    END

    -- Validar monto
    IF ( @inMontoRecibido < @MontoAPagar )
    BEGIN
        SET @outMessage = N'El monto recibido es insuficiente. Se necesita ₡' + CAST(@MontoAPagar AS NVARCHAR(50)) + '.';
        SET @outResultCode = 50004;
        RETURN;
    END

    -- 3. PREPARACIÓN DE PAGO Y CÓDIGO DE COMPROBANTE
    
    SET @outMontoFinalPagado = @MontoAPagar;
    
    -- Generar código de comprobante (Mantengo la lógica de CONCAT para compatibilidad)
    SET @ComprobanteCode = CONCAT('PAGO-', CAST(ABS(CHECKSUM(NEWID())) % 900000 + 100000 AS INT));
    SET @outCodigoComprobante = @ComprobanteCode;

    
    -- 4. PROCESAMIENTO TRANSACCIONAL
    
    BEGIN TRANSACTION;

    BEGIN TRY

        -- 4a. Actualizar estado de Factura
        UPDATE dbo.Factura
        SET
            Estado = 'Pagada'
        WHERE
            ( NumeroComprobante = @inNumeroComprobante );

        -- 4b. Insertar Comprobante de Pago
        INSERT INTO dbo.ComprobantePago
            (
              NumeroComprobanteFactura
            , FechaPago             
            , Monto
            , idTipoMedioPago
            )
        VALUES
            (
              @inNumeroComprobante
            , @inFechaOperacion      
            , @outMontoFinalPagado
            , @inIdTipoMedioPago
            );
        
        -- 4c. GESTIÓN DE RECONEXIÓN DE AGUA (Lógica Integrada)

        -- 4c.i. Buscar Orden de Corte pendiente asociada a esta factura
        SELECT TOP 1
              @idOrdenCortePendiente = OCA.id
        FROM dbo.OrdenCorteAgua AS OCA
        WHERE (OCA.NumeroComprobante = @inNumeroComprobante)
          AND (OCA.Estado = 1); -- Asumiendo 1 = Pendiente de pago/reconexión

        IF (@idOrdenCortePendiente IS NOT NULL)
        BEGIN
            -- 4c.ii. Generar la Orden de Reconexión de Agua
            INSERT INTO dbo.OrdenReconexionAgua
                (
                  idOrdenCorte
                , FechaReconexion       
                )
            VALUES
                (
                  @idOrdenCortePendiente
                , @inFechaOperacion      
                );

            -- 4c.iii. Cerrar la Orden de Corte
            UPDATE dbo.OrdenCorteAgua
            SET
                Estado = 2 -- Asumiendo 2 = Pagado/Reconexión solicitada
            WHERE
                ( id = @idOrdenCortePendiente );
        END

        COMMIT TRANSACTION;

        -- 4d. Variables de Salida Finales
        SET @outSuccess = 1;
        SET @outMessage = N'Pago registrado con éxito. El monto final pagado (incluyendo intereses) fue de ₡' + CAST(@outMontoFinalPagado AS NVARCHAR(50)) + '.';

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        
        INSERT INTO dbo.DBErrors
            (
              UserName
            , ErrorNumber
            , ErrorState
            , ErrorSeverity
            , ErrorLine
            , ErrorProcedure
            , ErrorMessage
            , ErrorDateTime
            )
        VALUES
            (
              SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , GETDATE()
            );

        SET @outMessage = N'Error transaccional al procesar el pago: ' + ERROR_MESSAGE();
        SET @outSuccess = 0;
        SET @outResultCode = 50005;

    END CATCH;
END
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

    
    -- 3. INSERCIÓN DE FACTURAS 
    
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

    
    -- 4. INSERCIÓN DE DETALLE DE FACTURA 
    
    -- 4a. Impuesto Propiedad (CC 3)
    INSERT INTO dbo.DetalleFactura
        (NumeroComprobante
        , idConceptoCobro
        , Monto
        , Descripcion) -- 
    SELECT
          F.NumeroComprobante
        , 3
        , CAST((P.ValorFiscal * CC.ValorPorcentual) / 12.0 AS MONEY)
        , 'Impuesto de Propiedad' --
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
        , Descripcion) -- 
    SELECT
          F.NumeroComprobante
        , 4
        , CAST(CC.ValorFijo AS MONEY) +
        CASE
            WHEN (P.MetrosCuadrados > 400)
            THEN CAST(CEILING((P.MetrosCuadrados - 400.0) / 200.0) * 75.0 AS MONEY)
            ELSE CAST(0.0 AS MONEY)
        END
        , 'Recolección de Basura' -- 
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
        , Descripcion) -- 
    SELECT
          F.NumeroComprobante
        , 5
        , CAST(CC.ValorFijo / 12.0 AS MONEY)
        , 'Mantenimiento de Parques' 
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
        , Descripcion) -- 
    SELECT
          F.NumeroComprobante
        , 1
        , CConsumo.MontoConsumo
        , CONCAT('Consumo de Agua (', CConsumo.ConsumoM3, ' m3)') -- 
    FROM dbo.Factura AS F
    INNER JOIN @CalculoConsumo AS CConsumo
        ON (CConsumo.NumeroFinca = F.NumeroFinca)
    WHERE (F.FechaGeneracion = @inFecha);

    -- 4e. Patente Comercial (CC 2)
    INSERT INTO dbo.DetalleFactura
        (NumeroComprobante
        , idConceptoCobro
        , Monto
        , Descripcion) -- 
    SELECT
          F.NumeroComprobante
        , 2
        , CAST(CC.ValorFijo / 6.0 AS MONEY) -- ValorFijo (Semestral) dividido entre 6 meses.
        , 'Patente Comercial Mensual' -- 
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
        , Descripcion) 
    SELECT
          F.NumeroComprobante
        , 7
        , CAST(CC.ValorFijo AS MONEY) -- Monto Fijo de Reconexión
        , 'Reconexión de Servicio de Agua' 
    FROM dbo.Factura AS F
    INNER JOIN dbo.ConceptoCobro AS CC
        ON (CC.id = 7)
    INNER JOIN dbo.CCPropiedad AS CCP
        ON (CCP.NumeroFinca = F.NumeroFinca)
       AND (CCP.idConceptoCobro = 7) -- Se aplica si la finca tiene asociado este concepto
    WHERE (CCP.idTipoAsociacion = 1)
      AND (F.FechaGeneracion = @inFecha);


    -- 5. ACTUALIZAR SALDOS Y TOTALES 
    
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


    -- 6. APLICAR INTERESES MORATORIOS 
    
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
