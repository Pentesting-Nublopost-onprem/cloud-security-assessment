#!/usr/bin/env python3
"""Genera informe-final.pdf a partir de informe-final.md.

El Markdown es la fuente única: la portada sale de su tabla inicial, el índice
de sus títulos y los diagramas de sus bloques Mermaid.

Requisitos (Linux): pandoc 3, Mermaid CLI (mmdc), WeasyPrint 66 o posterior,
BeautifulSoup 4 y las fuentes TeX Gyre Termes, TeX Gyre Heros y DejaVu Sans Mono.

Uso, desde la raíz del repositorio:
    python3 reports/final-report/build/build_pdf.py
"""

import json
import re
import subprocess
import tempfile
from html import escape
from pathlib import Path

from bs4 import BeautifulSoup
from weasyprint import HTML

BUILD = Path(__file__).resolve().parent
INFORME = BUILD.parent
FUENTE = INFORME / "informe-final.md"
SALIDA = INFORME / "informe-final.pdf"
ESTILO = BUILD / "informe.css"

MERMAID = {
    "theme": "neutral",
    "themeVariables": {"fontFamily": "TeX Gyre Heros, Helvetica, Arial, sans-serif"},
    "flowchart": {"curve": "basis"},
}


def ficha(md):
    """Campos de la tabla inicial del informe: | **Campo** | Valor |."""
    return {campo: valor.strip()
            for campo, valor in re.findall(r"^\| \*\*(.+?)\*\* \| (.+?) \|$", md, flags=re.M)}


def portada(md, datos):
    tipo, _, cliente = re.search(r"^# (.+)$", md, flags=re.M).group(1).partition(" · ")
    titulo, _, subtitulo = re.search(r"^\*\*(.+?)\*\*$", md, flags=re.M).group(1).partition(": ")
    repo = datos["Repositorio"]
    filas = [
        ("Autor", escape(datos["Autor"])),
        ("Proyecto", escape(datos["Proyecto"])),
        ("Cliente", escape(datos["Cliente"])),
        ("Versión", escape(datos["Versión"])),
        ("Repositorio", f'<a href="{escape(repo)}">{escape(repo)}</a>'),
    ]
    tabla = "".join(f"<tr><td>{c}</td><td>{v}</td></tr>" for c, v in filas)
    html = f"""
<section class="portada" data-autor="{escape(datos['Autor'])}">
  <p class="tipo">{escape(tipo)}</p>
  <h1>{escape(titulo)}</h1>
  <p class="subtitulo">{escape(subtitulo)}</p>
  <p class="cliente">{escape(cliente)} · infraestructura híbrida Azure + on-premise</p>
  <div class="raya"></div>
  <table class="datos">{tabla}</table>
  <p class="aviso">{escape(datos['Confidencialidad'])}.</p>
</section>"""
    meta = {"titulo": f"{titulo} · {tipo}", "autor": datos["Autor"]}
    return html, meta


def diagramas(md, tmp):
    """Sustituye cada bloque Mermaid por un PNG generado con mmdc."""
    config = tmp / "mermaid.json"
    config.write_text(json.dumps(MERMAID), encoding="utf-8")
    contador = 0

    def render(bloque):
        nonlocal contador
        contador += 1
        fuente = tmp / f"diagrama-{contador}.mmd"
        png = tmp / f"diagrama-{contador}.png"
        fuente.write_text(bloque.group(1), encoding="utf-8")
        subprocess.run(["mmdc", "-q", "-i", str(fuente), "-o", str(png), "-c", str(config),
                        "-b", "white", "-s", "3"], check=True)
        return f'<figure class="diagrama"><img src="{png.as_uri()}" alt="Diagrama"></figure>\n'

    return re.sub(r"^```mermaid\n(.*?)^```\n", render, md, flags=re.M | re.S)


def a_html(md):
    resultado = subprocess.run(
        ["pandoc", "-f", "gfm", "-t", "html5", "--no-highlight", "--wrap=none"],
        input=md, capture_output=True, text=True, check=True)
    return BeautifulSoup(resultado.stdout, "html.parser")


def tablas(sopa):
    """Anchos automáticos; las tablas de dos columnas sin cabecera son fichas."""
    for tabla in sopa.find_all("table"):
        for grupo in tabla.find_all("colgroup"):
            grupo.decompose()
        for celda in tabla.find_all(["th", "td"]):
            celda.attrs.pop("style", None)
        cabecera = tabla.find("thead")
        if cabecera is not None and not cabecera.get_text(strip=True):
            cabecera.decompose()
            cabecera = None
        filas = tabla.find_all("tr")
        if cabecera is None and filas and all(len(f.find_all("td")) == 2 for f in filas):
            tabla["class"] = tabla.get("class", []) + ["ficha"]


def fichas(sopa):
    """Convierte la ficha de cada hallazgo en bloques y la une a su título.

    WeasyPrint puede partir una tabla entre páginas aunque se pida lo contrario;
    con bloques, título y ficha quedan siempre en la misma página.
    """
    for tabla in sopa.select("table.ficha"):
        anterior = tabla.find_previous_sibling()
        bloque = sopa.new_tag("div", attrs={"class": "bloque-ficha"})
        tabla.insert_before(bloque)
        if anterior is not None and anterior.name == "h4":
            bloque.append(anterior.extract())
        ficha_div = sopa.new_tag("div", attrs={"class": "ficha"})
        for fila in tabla.find_all("tr"):
            campo, valor = fila.find_all("td")
            div_fila = sopa.new_tag("div", attrs={"class": "fila"})
            for celda, clase in ((campo, "campo"), (valor, "valor")):
                div = sopa.new_tag("div", attrs={"class": clase})
                for nodo in list(celda.contents):
                    div.append(nodo.extract())
                div_fila.append(div)
            ficha_div.append(div_fila)
        bloque.append(ficha_div)
        tabla.decompose()


def figuras(sopa):
    """Une cada captura con su pie («*Figura N · texto*») en un <figure>."""
    for pie_md in sopa.find_all("p"):
        enfasis = pie_md.find("em")
        if enfasis is None or len(pie_md.contents) != 1 or not enfasis.get_text().startswith("Figura "):
            continue
        anterior = pie_md.find_previous_sibling()
        if anterior is None or anterior.name != "p" or len(anterior.contents) != 1 or anterior.img is None:
            continue
        figura = sopa.new_tag("figure")
        figura.append(anterior.img.extract())
        pie = sopa.new_tag("figcaption")
        numero, _, resto = str(enfasis.contents[0]).partition(" · ")
        etiqueta = sopa.new_tag("strong")
        etiqueta.string = f"{numero}."
        pie.append(etiqueta)
        pie.append(" " + resto)
        for nodo in list(enfasis.contents[1:]):
            pie.append(nodo.extract())
        figura.append(pie)
        anterior.replace_with(figura)
        pie_md.decompose()


def secciones(sopa):
    """Agrupa cada <h2> con su contenido en <section id="sec-…"> (estilos por sección)."""
    for titulo in sopa.find_all("h2", recursive=False):
        seccion = sopa.new_tag("section", id=f"sec-{titulo.get('id', '')}")
        titulo.insert_before(seccion)
        nodo = titulo
        while nodo is not None and not (nodo is not titulo and nodo.name == "h2"):
            siguiente = nodo.next_sibling
            seccion.append(nodo.extract())
            nodo = siguiente


def indice(sopa):
    nav = BeautifulSoup('<nav class="indice"><h2 id="indice">Índice</h2><ol></ol></nav>',
                        "html.parser")
    lista = nav.find("ol")
    for titulo in sopa.find_all(["h2", "h3", "h4"]):
        if not titulo.get("id"):
            continue
        entrada = nav.new_tag("li", attrs={"class": f"n{titulo.name[1]}"})
        enlace = nav.new_tag("a", href=f"#{titulo['id']}")
        enlace.string = " ".join(titulo.get_text().split())
        entrada.append(enlace)
        lista.append(entrada)
    return nav


def main():
    md = FUENTE.read_text(encoding="utf-8")
    datos = ficha(md)
    cabecera, meta = portada(md, datos)
    with tempfile.TemporaryDirectory() as directorio:
        cuerpo_md = md[re.search(r"^## 1\. ", md, flags=re.M).start():]
        sopa = a_html(diagramas(cuerpo_md, Path(directorio)))
        tablas(sopa)
        fichas(sopa)
        figuras(sopa)
        secciones(sopa)
        documento = f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>{escape(meta['titulo'])}</title>
<meta name="author" content="{escape(meta['autor'])}">
<meta name="description" content="Informe de pentest de caja blanca de una infraestructura híbrida Azure + on-premise (metodología CEH).">
<meta name="keywords" content="pentest, caja blanca, Azure, Kubernetes, API, CEH, CVSS">
</head>
<body>
{cabecera}
{indice(sopa)}
{sopa}
</body>
</html>"""
        HTML(string=documento, base_url=str(INFORME)).write_pdf(SALIDA, stylesheets=[str(ESTILO)])
    print(f"PDF generado: {SALIDA}")


if __name__ == "__main__":
    main()
