# -*- coding: latin-1 -*-
# Generador de ficheros ESC/POS de ejemplo para el visor.
# Crea varios tickets en ../ejemplos/*.escpos con los comandos que
# interpreta EscPosRenderer. Texto codificado en Latin-1 (byte a byte).
#
# Uso: python generar_ejemplos.py
import math
import os

ESC = b"\x1b"
GS = b"\x1d"
N_CHAR_LIN = 42


class EscPos:
    def __init__(self):
        self.buf = bytearray()

    def raw(self, datos):
        self.buf += datos

    def txt(self, s):
        self.buf += s.encode("latin-1", "replace")

    def linea(self, s=""):
        self.txt(s)
        self.raw(b"\r\n")

    def inicializar(self):
        self.raw(ESC + b"@")

    def fuente(self, n):  # 0=A(12x24) 1=B(9x17) 2=C(7x14)
        self.raw(ESC + b"M" + bytes([n]))

    def negrita(self, on):
        self.raw(ESC + b"E" + bytes([1 if on else 0]))

    def subrayado(self, on):
        self.raw(ESC + b"-" + bytes([1 if on else 0]))

    def alinear(self, n):  # 0=izq 1=centro 2=der
        self.raw(ESC + b"a" + bytes([n]))

    def inverso(self, on):
        self.raw(GS + b"B" + bytes([1 if on else 0]))

    def tamano(self, ancho, alto):  # multiplicadores 1-8
        self.raw(GS + b"!" + bytes([(ancho - 1) | ((alto - 1) << 4)]))

    def saltar(self, n):
        self.raw(ESC + b"d" + bytes([n]))

    def cortar(self):
        self.raw(ESC + b"i")

    def separador(self, car="-"):
        self.linea(car * N_CHAR_LIN)

    def columnas(self, izq, der, ancho=N_CHAR_LIN):
        esp = max(1, ancho - len(izq) - len(der))
        self.linea(izq + " " * esp + der)

    def qr(self, texto, modulo=8, nivel=48):  # nivel: 48=L 49=M 50=Q 51=H
        datos = texto.encode("latin-1", "replace")
        dl = len(datos) + 3
        self.raw(GS + b"(k\x04\x00\x31\x41\x32\x00")               # modelo
        self.raw(GS + b"(k\x03\x00\x31\x43" + bytes([modulo]))     # módulo
        self.raw(GS + b"(k\x03\x00\x31\x45" + bytes([nivel]))      # nivel
        self.raw(GS + b"(k" + bytes([dl % 256, dl // 256]) +
                 b"\x31\x50\x30" + datos)                          # datos
        self.raw(GS + b"(k\x03\x00\x31\x51\x30")                   # imprimir
        self.raw(b"\r\n")

    def raster(self, pixeles):
        # pixeles: lista de filas; cada fila lista de 0/1
        alto = len(pixeles)
        ancho = len(pixeles[0])
        ancho_bytes = (ancho + 7) // 8
        self.raw(GS + b"v0\x00" +
                 bytes([ancho_bytes % 256, ancho_bytes // 256]) +
                 bytes([alto % 256, alto // 256]))
        for fila in pixeles:
            b = bytearray(ancho_bytes)
            for x, p in enumerate(fila):
                if p:
                    b[x // 8] |= 0x80 >> (x % 8)
            self.raw(bytes(b))
        self.raw(b"\r\n")

    def guardar(self, ruta):
        with open(ruta, "wb") as f:
            f.write(self.buf)
        print(f"{ruta}  ({len(self.buf)} bytes)")


def logo_pixeles(ancho=240, alto=120):
    # Logo geométrico: anillo con rombo interior y barras laterales
    pix = [[0] * ancho for _ in range(alto)]
    cx, cy = ancho // 2, alto // 2
    r_ext, r_int = 55, 45
    for y in range(alto):
        for x in range(ancho):
            d = math.hypot(x - cx, y - cy)
            if r_int <= d <= r_ext:
                pix[y][x] = 1                      # anillo
            if abs(x - cx) / 2 + abs(y - cy) <= 28:
                pix[y][x] = 1                      # rombo
            if 10 <= y <= alto - 10 and (x < 12 or x >= ancho - 12):
                if (y // 6) % 2 == 0:
                    pix[y][x] = 1                  # barras punteadas
    return pix


def ticket_cafeteria(ruta):
    t = EscPos()
    t.inicializar()
    t.alinear(1)
    t.tamano(2, 2)
    t.negrita(True)
    t.linea("CAFETERIA SOL")
    t.tamano(1, 1)
    t.negrita(False)
    t.linea("Plaza Mayor 4 - Zamora")
    t.linea("NIF: 12345678Z - Tel: 980 000 000")
    t.alinear(0)
    t.separador()
    t.columnas("2 x Cafe con leche", "3,00")
    t.columnas("1 x Tostada con tomate", "2,50")
    t.columnas("1 x Zumo de naranja", "3,20")
    t.columnas("2 x Pincho tortilla", "5,00")
    t.separador()
    t.negrita(True)
    t.tamano(1, 2)
    t.columnas("TOTAL", "13,70 EUR", 20)
    t.tamano(1, 1)
    t.negrita(False)
    t.fuente(1)
    t.columnas("IVA 10% incluido", "1,25")
    t.fuente(0)
    t.separador()
    t.alinear(1)
    t.qr("https://example.com/ticket/000123", 8)
    t.linea("Gracias por su visita")
    t.fuente(2)
    t.linea("Mesa 4 - Camarero: Luis - 11/07/2026 10:32")
    t.fuente(0)
    t.saltar(3)
    t.cortar()
    t.guardar(ruta)


def ticket_supermercado(ruta):
    t = EscPos()
    t.inicializar()
    t.alinear(1)
    t.inverso(True)
    t.tamano(2, 2)
    t.linea(" SUPERZAM ")
    t.tamano(1, 1)
    t.inverso(False)
    t.linea("Avda. Tres Cruces 21 - Zamora")
    t.linea("www.superzam.example")
    t.alinear(0)
    t.separador("=")
    t.fuente(1)
    articulos = [
        ("LECHE ENTERA 1L x6", "5,10"),
        ("PAN DE MOLDE 680G", "1,45"),
        ("HUEVOS L DOCENA", "2,35"),
        ("ACEITE OLIVA VE 1L", "7,95"),
        ("MANZANA GOLDEN KG", "1,89"),
        ("POLLO ENTERO KG", "3,15"),
        ("ARROZ REDONDO 1KG", "1,05"),
        ("TOMATE FRITO 400G x3", "2,40"),
        ("DETERGENTE 30 LAV", "6,50"),
        ("PAPEL HIGIENICO x12", "4,20"),
        ("QUESO CURADO CUNA", "5,75"),
        ("AGUA MINERAL 6x1,5L", "2,10"),
    ]
    for nombre, precio in articulos:
        t.columnas(nombre, precio)
    t.fuente(0)
    t.separador("=")
    t.columnas("12 ARTICULOS", "")
    t.negrita(True)
    t.tamano(1, 2)
    t.columnas("TOTAL", "43,89", 20)
    t.tamano(1, 1)
    t.negrita(False)
    t.separador()
    t.fuente(1)
    t.columnas("ENTREGADO (TARJETA)", "43,89")
    t.linea()
    t.linea("DESGLOSE IVA   BASE      CUOTA")
    t.linea("  4%           9,13      0,37")
    t.linea(" 10%          21,32      2,13")
    t.linea(" 21%           8,96      1,88")
    t.fuente(0)
    t.separador()
    t.alinear(1)
    t.subrayado(True)
    t.linea("Devoluciones: 15 dias con ticket")
    t.subrayado(False)
    t.qr("TICKET:2026-07-11:000456:43.89", 6, 49)
    t.saltar(3)
    t.cortar()
    t.guardar(ruta)


def ticket_estilos(ruta):
    t = EscPos()
    t.inicializar()
    t.alinear(1)
    t.tamano(2, 2)
    t.linea("DEMO DE ESTILOS")
    t.tamano(1, 1)
    t.alinear(0)
    t.separador()
    t.linea("Fuente A (12x24) - normal")
    t.fuente(1)
    t.linea("Fuente B (9x17) - mas compacta")
    t.fuente(2)
    t.linea("Fuente C (7x14) - la mas pequena")
    t.fuente(0)
    t.separador()
    t.negrita(True)
    t.linea("Texto en negrita")
    t.negrita(False)
    t.subrayado(True)
    t.linea("Texto subrayado")
    t.subrayado(False)
    t.negrita(True)
    t.subrayado(True)
    t.linea("Negrita + subrayado")
    t.negrita(False)
    t.subrayado(False)
    t.inverso(True)
    t.linea(" Texto en modo inverso ")
    t.inverso(False)
    t.separador()
    for m in range(1, 5):
        t.tamano(m, m)
        t.linea(f"Tamano x{m}")
    t.tamano(1, 1)
    t.separador()
    t.linea("Ancho x2, alto x1:")
    t.tamano(2, 1)
    t.linea("ANCHO DOBLE")
    t.tamano(1, 1)
    t.linea("Ancho x1, alto x3:")
    t.tamano(1, 3)
    t.linea("ALTO TRIPLE")
    t.tamano(1, 1)
    t.saltar(3)
    t.cortar()
    t.guardar(ruta)


def ticket_alineaciones(ruta):
    t = EscPos()
    t.inicializar()
    t.alinear(1)
    t.tamano(2, 2)
    t.linea("ALINEACIONES")
    t.tamano(1, 1)
    t.alinear(0)
    t.separador()
    t.linea("<- Alineado a la izquierda")
    t.alinear(1)
    t.linea("- Centrado -")
    t.alinear(2)
    t.linea("Alineado a la derecha ->")
    t.alinear(0)
    t.separador()
    t.linea("Columnas izquierda/derecha:")
    t.columnas("Concepto", "Importe")
    t.columnas("Alquiler local", "650,00")
    t.columnas("Suministros", "82,40")
    t.separador()
    t.linea("Salto de 5 lineas (ESC d):")
    t.saltar(5)
    t.linea("...y seguimos aqui")
    t.separador()
    t.alinear(1)
    t.linea("Linea de corte parcial abajo")
    t.saltar(2)
    t.cortar()
    t.linea("Segundo bloque tras el corte")
    t.saltar(3)
    t.cortar()
    t.guardar(ruta)


def ticket_qr(ruta):
    t = EscPos()
    t.inicializar()
    t.alinear(1)
    t.tamano(2, 2)
    t.linea("CODIGOS QR")
    t.tamano(1, 1)
    t.separador()
    t.linea("Modulo 4 - nivel L")
    t.qr("https://example.com/qr-pequeno", 4, 48)
    t.linea("Modulo 8 - nivel M")
    t.qr("https://example.com/qr-mediano", 8, 49)
    t.linea("Modulo 12 - nivel H")
    t.qr("https://example.com/qr-grande", 12, 51)
    t.separador()
    t.alinear(0)
    t.linea("QR alineado a la izquierda:")
    t.qr("IZQUIERDA", 6)
    t.alinear(2)
    t.linea("QR alineado a la derecha:")
    t.qr("DERECHA", 6)
    t.alinear(1)
    t.separador()
    t.fuente(1)
    t.linea("QR largo (URL con parametros)")
    t.fuente(0)
    t.qr("https://example.com/factura?serie=A&numero=2026-000123"
         "&nif=12345678Z&total=43.89&fecha=2026-07-11", 6, 50)
    t.saltar(3)
    t.cortar()
    t.guardar(ruta)


def ticket_raster(ruta):
    t = EscPos()
    t.inicializar()
    t.alinear(1)
    t.tamano(2, 2)
    t.linea("IMAGEN RASTER")
    t.tamano(1, 1)
    t.linea("(comando GS v 0)")
    t.separador()
    t.raster(logo_pixeles())
    t.linea("Logo generado por codigo")
    t.separador()
    t.alinear(0)
    t.linea("Izquierda:")
    t.raster(logo_pixeles(96, 48))
    t.alinear(2)
    t.linea("Derecha:")
    t.raster(logo_pixeles(96, 48))
    t.alinear(1)
    t.saltar(3)
    t.cortar()
    t.guardar(ruta)


def entrada_concierto(ruta):
    t = EscPos()
    t.inicializar()
    t.alinear(1)
    t.inverso(True)
    t.tamano(2, 2)
    t.linea(" ENTRADA ")
    t.tamano(1, 1)
    t.inverso(False)
    t.saltar(1)
    t.tamano(2, 3)
    t.negrita(True)
    t.linea("LOS DELPHI")
    t.tamano(1, 1)
    t.negrita(False)
    t.linea("Gira 2026 - Object Pascal Tour")
    t.separador("*")
    t.alinear(0)
    t.columnas("Fecha:", "sabado 25/07/2026")
    t.columnas("Apertura puertas:", "20:00")
    t.columnas("Recinto:", "Plaza de Toros")
    t.columnas("Ciudad:", "Zamora")
    t.separador()
    t.negrita(True)
    t.tamano(1, 2)
    t.columnas("ZONA PISTA", "35,00 EUR", 20)
    t.tamano(1, 1)
    t.negrita(False)
    t.fuente(1)
    t.columnas("Localidad:", "PISTA-B / Fila general")
    t.columnas("Entrada:", "E-2026-071535")
    t.fuente(0)
    t.separador()
    t.alinear(1)
    t.linea("Presente este codigo en el acceso")
    t.qr("ENTRADA|E-2026-071535|LOSDELPHI|20260725|PISTA", 10, 51)
    t.fuente(2)
    t.linea("Prohibida la reventa. No se admiten devoluciones.")
    t.linea("La organizacion se reserva el derecho de admision.")
    t.fuente(0)
    t.saltar(3)
    t.cortar()
    t.guardar(ruta)


if __name__ == "__main__":
    destino = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "ejemplos")
    os.makedirs(destino, exist_ok=True)
    ticket_cafeteria(os.path.join(destino, "01_cafeteria.escpos"))
    ticket_supermercado(os.path.join(destino, "02_supermercado.escpos"))
    ticket_estilos(os.path.join(destino, "03_estilos_texto.escpos"))
    ticket_alineaciones(os.path.join(destino, "04_alineaciones.escpos"))
    ticket_qr(os.path.join(destino, "05_codigos_qr.escpos"))
    ticket_raster(os.path.join(destino, "06_imagen_raster.escpos"))
    entrada_concierto(os.path.join(destino, "07_entrada_concierto.escpos"))
