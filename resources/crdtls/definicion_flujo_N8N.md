# Flujo N8N
## Objetivo del flujo 
EL objetivo es la creacion de una solucion robusta y profesional de consulta de documentos empresarial a traés de un rag hibrido multimodal , con funciones de cag y kag todo interconectado entre si de la mejor forma posible. 

Este Rag se conectara a la nube de datos de la empresa , (Google drive oara el POC, pero debera adaptarse a sharepoint confluence en el futuro)


## Partes del flujo 

- Paso1 - Activacion del flujo: Se sube , se modifica o se elimina un archivo en googledrive
- Paso2 - Descarga del nuevo archivo o del archivo modificado o Eliminacion de la base de datos del archivo eliminado
- Paso3 - Separacion por tipo de archivo para el procesado: minimo: "pdf, xlsx , text, markdown, csv
- paso4...