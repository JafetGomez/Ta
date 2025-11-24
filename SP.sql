USE [Facturacion]
GO
/****** Object:  StoredProcedure [dbo].[SP_BuscarFacturaPendiente]    Script Date: 27/11/2025 16:05:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_BuscarFacturaPendiente]
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
    DECLARE @InteresCCID            INT  = 6; 
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

    SELECT TOP 1
          T1.NumeroComprobante
        , T1.NumeroFinca
        , T1.FechaGeneracion
        , T1.FechaVencimiento
        , T1.TotalAPagarOriginal
        , T1.TotalAPagarFinal
        , T1.Detalle
    FROM
        dbo.Factura AS T1
    WHERE
        ( T1.NumeroFinca = @inNumeroFinca )
        AND ( T1.Estado = 'Pendiente' )
    ORDER BY
        T1.FechaVencimiento ASC;

END
GO
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
/****** Object:  StoredProcedure [dbo].[SP_ProcesarPago]    Script Date: 27/11/2025 16:05:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_ProcesarPago]
    @inNumeroComprobante    INT
  , @inNumeroFinca          VARCHAR(64)
  , @inMontoRecibido        FLOAT
  , @inNumeroReferencia     VARCHAR(64)
  , @inIdTipoMedioPago      INT
  , @outSuccess             BIT OUTPUT
  , @outMessage             NVARCHAR(255) OUTPUT
  , @outMontoFinalPagado    FLOAT OUTPUT
  , @outCodigoComprobante   VARCHAR(64) OUTPUT
  , @outResultCode          INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outSuccess             = 0;
    SET @outMontoFinalPagado    = 0;
    SET @outCodigoComprobante   = NULL;
    SET @outResultCode          = 0;

    DECLARE @MontoAPagar    FLOAT;
    DECLARE @EstadoActual   VARCHAR(64);
    DECLARE @Hoy            DATE = CAST(GETDATE() AS DATE);
    DECLARE @ComprobanteCode  VARCHAR(64);

    SELECT TOP 1
          @MontoAPagar    = T1.TotalAPagarFinal
        , @EstadoActual   = T1.Estado
    FROM
        dbo.Factura AS T1
    WHERE
          ( T1.NumeroComprobante = @inNumeroComprobante )
      AND ( T1.NumeroFinca = @inNumeroFinca );

    IF ( @MontoAPagar IS NULL )
    BEGIN
        SET @outMessage = N'Factura no encontrada o no pertenece a la finca.';
        SET @outResultCode = 50002;
        RETURN;
    END

    IF ( @EstadoActual <> 'Pendiente' )
    BEGIN
        SET @outMessage = N'Factura ya está en estado: ' + @EstadoActual + '.';
        SET @outResultCode = 50003;
        RETURN;
    END

    IF ( @inMontoRecibido < @MontoAPagar )
    BEGIN
        SET @outMessage = N'El monto recibido es insuficiente. Se necesita ₡' + CAST(@MontoAPagar AS NVARCHAR(50)) + '.';
        SET @outResultCode = 50004;
        RETURN;
    END

    SET @outMontoFinalPagado = @MontoAPagar;
    
    SET @ComprobanteCode = CONCAT('PAGO-', CAST(ABS(CHECKSUM(NEWID())) % 900000 + 100000 AS INT));
    SET @outCodigoComprobante = @ComprobanteCode;

    BEGIN TRANSACTION;

    BEGIN TRY

        UPDATE dbo.Factura
        SET
            Estado = 'Pagada'
        WHERE
            ( NumeroComprobante = @inNumeroComprobante );

        INSERT INTO dbo.ComprobantePago
            (
              NumeroComprobanteFactura
            , FechaPago
            , Monto
            , NumeroReferencia
            , IdTipoMedioPago
            )
        VALUES
            (
              @inNumeroComprobante
            , @Hoy
            , @outMontoFinalPagado
            , @inNumeroReferencia
            , @inIdTipoMedioPago
            );

        COMMIT TRANSACTION;

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
GO
