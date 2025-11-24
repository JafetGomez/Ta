const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const sql = require('mssql'); // Importamos el módulo mssql

const app = express();
const PORT = 3000;

// ====================================================================
// 1. CONFIGURACIÓN DE CONEXIÓN A SQL SERVER
// ====================================================================
const dbConfig = {


    server: '172.235.134.93', 
    port: 1433,             
    database: 'Facturacion',

    user: 'pruebasDB',        
    password: 'BD1g22025*', 
    
    options: {
        trustedConnection: false, 
        enableArithAbort: true,
        trustServerCertificate: true, 
    },
};

let pool;
try {
    pool = new sql.ConnectionPool(dbConfig);
    pool.connect(err => {
        if (err) {
            console.error('Error al conectar a SQL Server:', err.message);
        } else {
            console.log('Conexión a SQL Server establecida con éxito.');
            pool.query('SELECT 1 as test', (qErr, qResult) => {
                if (qErr) {
                    console.error('Error al ejecutar consulta de prueba:', qErr);
                } else {
                    console.log('Consulta de prueba exitosa:', qResult.recordset);
                }
            });
        }
    });
} catch (error) {
    console.error('Error al inicializar el pool de conexión:', error.message);
}


// Configuración de Middlewares
app.use(cors());
app.use(bodyParser.json());

// ====================================================================
// 2. FUNCIÓN DE AUTENTICACIÓN (Llama a SP_LoginAdmin)
// ====================================================================
async function authenticateAdmin(username, password) {
    if (!pool || !pool.connected) {
        return { success: false, message: 'La conexión a la base de datos no está disponible.' };
    }

    try {
        const request = pool.request();
        
        request.input('Username', sql.VarChar(64), username);
        request.input('Password', sql.VarChar(100), password);

        // Llamada al Stored Procedure para Login: SP_LoginAdmin
        const result = await request.execute('SP_LoginAdmin');

        if (result.recordset.length > 0) {
            const user = result.recordset[0];
            return { success: true, message: 'Autenticación exitosa', user: { id: user.id, nombre: user.nombre } };
        } else {
            return { success: false, message: 'Credenciales inválidas. Verifica usuario y contraseña.' };
        }

    } catch (error) {
        console.error('Error en la autenticación con SQL (SP_LoginAdmin):', error);
        return { success: false, message: 'Error interno del servidor al consultar la base de datos.' };
    }
}

// ====================================================================
// ENDPOINT 1: LOGIN
// ====================================================================

app.post('/api/login', async (req, res) => {
    const { username, password } = req.body;

    // Validación básica de entrada
    if (!username || !password) {
        return res.status(400).json({ success: false, message: 'Faltan parámetros de usuario o contraseña.' });
    }

    try {
        const pool = await sql.connect(dbConfig);
        
        const request = pool.request();
        
        request.input('inUsername', sql.VarChar(64), username);
        request.input('inPassword', sql.VarChar(100), password);
        
        request.output('outResultCode', sql.Int);

        const result = await request.execute('SP_LoginAdmin');

        if (result.recordset.length > 0) {
            // Usuario encontrado
            const adminUser = result.recordset[0];
            res.status(200).json({ 
                success: true, 
                message: 'Autenticación exitosa.', 
                user: { id: adminUser.id, nombre: adminUser.nombre }
            });
        } else {
            // Credenciales incorrectas o usuario no encontrado
            res.status(401).json({ success: false, message: 'Credenciales inválidas.' });
        }

    } catch (error) {
        console.error('Error en la autenticación con SQL (SP_LoginAdmin):', error);
        res.status(500).json({ 
            success: false, 
            message: 'Error interno del servidor al intentar autenticar.',
            sqlError: error.message 
        });
    }
});

// ====================================================================
// ENDPOINT 2: BÚSQUEDA DE PROPIEDAD (Llama a SP_BuscarPropiedad)
// ====================================================================

app.get('/api/propiedad/search', async (req, res) => {
    if (!pool || !pool.connected) return res.status(500).json({ success: false, message: 'Base de datos no conectada.' });

    const searchTerm = req.query.term;

    if (!searchTerm) {
        return res.status(400).json({ success: false, message: 'Debe proporcionar un término de búsqueda (Finca o ID).' });
    }

    try {
        const request = pool.request();
        
        request.input('inSearchTerm', sql.VarChar(64), searchTerm);
        request.output('outResultCode', sql.Int);

        // Llamada al Stored Procedure para Búsqueda de Propiedad
        const result = await request.execute('SP_BuscarPropiedad');

        if (result.recordset.length > 0) {
            res.json({ success: true, property: result.recordset[0] });
        } else {
            res.status(404).json({ success: false, message: 'Propiedad no encontrada con el término de búsqueda.' });
        }

    } catch (error) {
        console.error('Error en búsqueda de propiedad (SP_BuscarPropiedad):', error);
        res.status(500).json({ success: false, message: 'Error interno del servidor al buscar propiedad.' });
    }
});


// ====================================================================
// ENDPOINT 3: BUSCAR FACTURA PENDIENTE MÁS VIEJA (Llama a SP_BuscarFacturaPendiente)
// ====================================================================

app.get('/api/factura/oldest-pending/:numeroFinca', async (req, res) => {
    if (!pool || !pool.connected) return res.status(500).json({ success: false, message: 'Base de datos no conectada.' });

    const numeroFinca = req.params.numeroFinca;

    try {
        const request = pool.request();
        
        request.input('inNumeroFinca', sql.VarChar(64), numeroFinca);
        request.output('outResultCode', sql.Int);

        // Llamada al Stored Procedure para buscar la factura más antigua pendiente
        const result = await request.execute('SP_BuscarFacturaPendiente');
        
        if (result.recordset.length > 0) {
            // El front-end debe usar el campo TotalAPagarFinal del registro devuelto
            res.json({ success: true, invoice: result.recordset[0] });
        } else {
            // Si no se encuentra factura, el SP debería devolver un recordset vacío o usar el outResultCode.
            res.json({ success: false, message: 'No hay facturas pendientes para esta propiedad.' });
        }

    } catch (error) {
        console.error('Error al buscar factura pendiente (SP_BuscarFacturaPendiente):', error.message);
        res.status(500).json({ success: false, message: 'Error interno del servidor al buscar factura.' });
    }
});


// ====================================================================
// ENDPOINT 4: PROCESAR PAGO (Llama a SP_ProcesarPago)
// ====================================================================

app.post('/api/factura/pay', async (req, res) => {
    if (!pool || !pool.connected) return res.status(500).json({ success: false, message: 'Base de datos no conectada.' });

    const { numeroComprobante, numeroFinca, montoPago, numeroReferencia, idTipoMedioPago } = req.body;

    if (!numeroComprobante || !numeroFinca || montoPago === undefined || !numeroReferencia || !idTipoMedioPago) {
        return res.status(400).json({ success: false, message: 'Faltan parámetros requeridos para el pago.' });
    }
    
    try {
        const request = pool.request();
        
        request.input('inNumeroComprobante', sql.Int, numeroComprobante);
        request.input('inNumeroFinca', sql.VarChar(64), numeroFinca);
        request.input('inMontoRecibido', sql.Float, montoPago); 
        request.input('inNumeroReferencia', sql.VarChar(64), numeroReferencia);
        request.input('inIdTipoMedioPago', sql.Int, idTipoMedioPago);
        
        request.output('outSuccess', sql.Bit);
        request.output('outMessage', sql.NVarChar(255));
        request.output('outMontoFinalPagado', sql.Float);
        request.output('outCodigoComprobante', sql.VarChar(64));
        request.output('outResultCode', sql.Int); 

        // 1. Ejecutar el Stored Procedure 
        const result = await request.execute('SP_ProcesarPago');
        
        const success = result.output.outSuccess;
        const message = result.output.outMessage;
        const montoFinal = result.output.outMontoFinalPagado;
        const codigo = result.output.outCodigoComprobante;
        const resultCode = result.output.outResultCode; 

        if (success) {
            res.json({ 
                success: true, 
                message: message, 
                pago: { codigo: codigo, monto: montoFinal }
            });
        } else {
            res.status(400).json({ 
                success: false, 
                message: message,
                resultCode: resultCode 
            });
        }

    } catch (error) {
        console.error('Error fatal al procesar el pago (SP_ProcesarPago):', error.message);
        res.status(500).json({ success: false, message: 'Error interno del servidor al procesar el pago.' });
    }
});

app.get('/api/factura/search-all', async (req, res) => {
    if (!pool || !pool.connected) return res.status(500).json({ success: false, message: 'Base de datos no conectada.' });

    const searchTerm = req.query.term; 

    if (!searchTerm) {
        return res.status(400).json({ success: false, message: 'Debe proporcionar un término de búsqueda (Finca o Identificación).' });
    }

    try {
        const request = pool.request();
        
        // 1. Parámetro de entrada del Stored Procedure
        request.input('inSearchTerm', sql.VarChar(64), searchTerm);
        request.output('outResultCode', sql.Int);

        // Llamada al Stored Procedure para buscar el historial
        const result = await request.execute('SP_BuscarFacturasPorTermino');

        // Obtener el código de resultado del output
        const resultCode = result.output.outResultCode;

        if (resultCode !== 0) {
            console.error(`SP_BuscarFacturasPorTermino terminó con código de error: ${resultCode}`);
            return res.status(500).json({ success: false, message: `Error interno de base de datos (${resultCode}) al consultar el historial.` });
        }

        // El SP devuelve todas las facturas (pagadas y pendientes) 
        if (result.recordset.length > 0) {
            res.json({ success: true, invoices: result.recordset });
        } else {
            res.json({ success: false, message: 'No se encontraron facturas para el término de búsqueda proporcionado.' });
        }

    } catch (error) {
        console.error('Error al buscar historial de facturas (SP_BuscarFacturasPorTermino):', error);
        res.status(500).json({ success: false, message: 'Error interno del servidor al consultar el historial.' });
    }
});



// Iniciar el servidor
app.listen(PORT, () => {
    console.log(`\n\n=== Servidor Node.js iniciado ===`);
    console.log(`Puerto: ${PORT}`);
    console.log('Endpoint de Login: http://localhost:3000/api/login');
    console.log('CONECTADO: Usando Stored Procedures para todas las operaciones de DB.'); 
    console.log('===================================\n');
});