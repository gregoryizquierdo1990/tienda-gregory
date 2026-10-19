-- ==============================================================================
-- MIGRACIÓN 51: CONFIGURAR PRODUCTOS CANVA COMO SERVICIOS (BAJO PEDIDO)
-- ==============================================================================
-- Convierte CANVA 30 DÍAS, CANVA 90 DÍAS y CANVA 180 DÍAS en tipo 'servicio'
-- para que se publiquen automáticamente en el catálogo de la tienda como
-- membresías Bajo Pedido sin requerir cuentas precargadas en inventario.
-- ==============================================================================

UPDATE public.products
SET 
    tipo = 'servicio',
    activo = true
WHERE nombre IN ('CANVA 30 DIAS', 'CANVA 90 DIAS', 'CANVA 180 DIAS');
