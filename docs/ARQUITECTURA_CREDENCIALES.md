Guía de Arquitectura y Configuración de Credenciales para n8n, Neo4j y Servicios de IA




Introducción


Este informe presenta un análisis exhaustivo y una guía de implementación para la configuración de credenciales en una arquitectura de automatización avanzada que integra n8n, una base de datos de grafos Neo4j y un servicio de inteligencia artificial personalizado, el DataLive Agent. La arquitectura descrita, que utiliza n8n como orquestador central para coordinar un grafo de conocimiento y un motor de IA, demuestra un alto grado de sofisticación.
El objetivo de este documento es trascender la simple configuración para establecer un marco de gestión de credenciales que sea seguro, escalable y mantenible. La gestión de secretos no es un mero paso de configuración, sino un pilar fundamental que garantiza la integridad, fiabilidad y seguridad de todo el sistema.
El informe se estructura de la siguiente manera: se comenzará por establecer los principios fundamentales de la gestión segura de credenciales en n8n. Posteriormente, se detallarán los patrones de implementación específicos para las credenciales de Neo4j y del DataLive Agent, contrastando los enfoques funcionales con las mejores prácticas arquitectónicas. Finalmente, se proporcionará un manual de solución de problemas diseñado para abordar los desafíos más comunes en un entorno de producción, seguido de un conjunto de recomendaciones estratégicas.
________________


Parte 1: Fundamentos de la Gestión Segura de Credenciales en n8n


Antes de abordar las configuraciones específicas, es crucial comprender los principios que rigen el manejo de información sensible en n8n. Estas bases justifican las prácticas recomendadas y son esenciales para construir un sistema robusto.


1.1 El Almacén de Credenciales de n8n: Un Enclave Seguro


El sistema de credenciales de n8n es mucho más que un simple formulario. Cuando se crea una credencial, n8n no la almacena como texto plano. En su lugar, la cifra y la guarda en su base de datos interna, creando un almacén seguro.1 Este es el principio fundamental por el cual se debe utilizar siempre el sistema de credenciales de n8n en lugar de alternativas inseguras.
La práctica de incrustar secretos —como claves de API, tokens o contraseñas— directamente en los parámetros de un nodo o en el JSON del flujo de trabajo es un antipatrón crítico. Aunque pueda parecer conveniente durante el desarrollo, expone información sensible en los logs de ejecución y en el propio archivo del flujo de trabajo, lo que representa un riesgo de seguridad significativo.
El flujo de datos seguro de n8n funciona de la siguiente manera: durante la ejecución de un flujo de trabajo, n8n recupera la credencial necesaria de su base de datos, la descifra en memoria, la inyecta en la solicitud saliente (por ejemplo, en una cabecera HTTP) y, una vez completada la operación, la descarta. En ningún momento el secreto en bruto queda expuesto en los logs de ejecución o en la definición del flujo de trabajo que se podría guardar en un sistema de control de versiones.2


1.2 Una Taxonomía de los Mecanismos de Autenticación en n8n


n8n ofrece una gama de mecanismos de autenticación, desde los más específicos hasta los más genéricos, para adaptarse a prácticamente cualquier servicio.
* Credenciales Dedicadas: Para servicios populares como AWS, Google Cloud, Shopify o ServiceNow, n8n proporciona tipos de credenciales predefinidos. Estos presentan formularios con campos específicos para ese servicio (por ejemplo, "Access Key ID" y "Secret Access Key" para AWS), ofreciendo la experiencia de configuración más sencilla y guiada.4
* Tipos de Credenciales Genéricas: Estos son los componentes flexibles para integrar servicios personalizados o APIs que no tienen un nodo dedicado. Son el foco principal de este informe.
   * Credenciales de HTTP Request: Se trata de una familia de métodos de autenticación integrados directamente en el nodo HTTP Request. Incluyen opciones como Basic Auth, Header Auth, Bearer Auth, OAuth2, entre otras.7 Permiten una configuración rápida para llamadas puntuales.
   * Tipos de Credenciales Genéricas (Reutilizables): Un enfoque más moderno y recomendado consiste en crear credenciales genéricas desde el menú principal de Credentials. Por ejemplo, se puede crear una credencial de tipo Header Auth una sola vez y luego seleccionarla en múltiples nodos HTTP Request. Esto promueve la reutilización y centraliza la gestión de secretos.3
* Credenciales de Nodos Comunitarios: Muchos nodos desarrollados por la comunidad para servicios específicos, como Neo4j, definen sus propios tipos de credenciales. A menudo, estas credenciales combinan los detalles de autenticación (usuario, contraseña) con otros parámetros de conexión (host, puerto, nombre de la base de datos), proporcionando una experiencia de configuración holística y superior.8


1.3 Gestión de Secretos para Producción: Más Allá de la Interfaz de Usuario


Si bien la creación de credenciales a través de la interfaz de usuario de n8n es segura, acopla la configuración de los secretos a la base de datos de una instancia específica de n8n. Este enfoque es adecuado para la creación de prototipos, pero presenta desafíos significativos en un entorno de producción, especialmente para la integración continua y el despliegue continuo (CI/CD), la replicación de entornos (desarrollo, preproducción, producción) y la recuperación ante desastres.
El estándar profesional para gestionar secretos en despliegues contenerizados es el uso de variables de entorno de n8n.12 Este método desacopla la configuración del entorno de ejecución.
Las variables clave para este propósito son:
* CREDENTIALS_OVERWRITE_DATA: Esta variable permite definir objetos de credenciales completos como una cadena JSON. Al iniciar, n8n leerá esta variable y creará o sobrescribirá las credenciales correspondientes en su base de datos, permitiendo una configuración totalmente programática.12
* El sufijo _FILE: Esta potente característica instruye a n8n para que lea el valor de una variable de entorno desde un archivo en lugar de directamente. Este es el método estándar para utilizar sistemas de gestión de secretos como Docker Secrets o Kubernetes Secrets. El secreto se monta como un archivo dentro del contenedor de n8n, y la variable de entorno simplemente apunta a la ruta de ese archivo, evitando que el secreto aparezca en la definición del contenedor.12
Por ejemplo, en un archivo docker-compose.yml, se puede montar un secreto y referenciarlo de la siguiente manera:


YAML




services:
 n8n:
   image: n8nio/n8n
   environment:
     - NEO4J_PASSWORD_FILE=/run/secrets/neo4j_password
   secrets:
     - neo4j_password

secrets:
 neo4j_password:
   file:./neo4j_password.txt

La elección de la estrategia de gestión de credenciales —interfaz de usuario frente a variables de entorno— es un indicador directo de la madurez operativa de un proyecto. Un sistema tan complejo y vital como el descrito en la consulta del usuario exige el enfoque más maduro y escalable basado en variables de entorno, ya que esto es lo que permitirá despliegues automatizados, consistentes y seguros en múltiples entornos.
________________


Parte 2: Configuración de la Conectividad con Neo4j: La Columna Vertebral del Grafo de Conocimiento


Esta sección aborda directamente el primer requisito: conectar n8n con Neo4j. Se analiza el método inferido por el usuario y se contrasta con un patrón arquitectónico superior que ofrece mayor funcionalidad y mantenibilidad.


2.1 Método 1: Acceso Directo a la API vía Nodo HTTP Request


La especificación del usuario de httpRequestAuth + basicAuth indica claramente la intención de utilizar el nodo genérico HTTP Request para interactuar con la API HTTP de Neo4j, que soporta autenticación básica.
Configuración Paso a Paso:
1. En la interfaz de n8n, navegar a Credentials y seleccionar New.2
2. Buscar y seleccionar el tipo de credencial HTTP Basic Auth.
3. Asignar un nombre descriptivo, por ejemplo, Neo4j-BasicAuth-Prod.
4. Introducir el User y la Password de la base de datos Neo4j.7
5. Guardar la credencial.
6. En un nodo HTTP Request del flujo de trabajo, en la sección Authentication, seleccionar Generic Credential Type.
7. Para Generic Auth Type, elegir HTTP Basic Auth.
8. En el desplegable Credential To Use, seleccionar la credencial Neo4j-BasicAuth-Prod creada anteriormente.
Aunque este método es funcional, presenta debilidades arquitectónicas significativas. Requiere la construcción manual de consultas Cypher dentro del cuerpo JSON del nodo HTTP Request, un proceso propenso a errores de sintaxis y difícil de mantener. Además, acopla fuertemente los flujos de trabajo a los detalles específicos del protocolo de la API HTTP de Neo4j. Cualquier cambio en la API podría requerir la modificación de múltiples nodos.


2.2 Método 2: El Patrón Recomendado - Nodos Comunitarios para Neo4j


Para ecosistemas maduros como Neo4j, la comunidad de n8n ya ha desarrollado soluciones más elegantes y robustas. El uso de un nodo dedicado para Neo4j abstrae las complejidades de la API subyacente y proporciona una interfaz de alto nivel optimizada para las operaciones con grafos.
Análisis de Nodos Comunitarios Disponibles:
* @Kurea/n8n-nodes-neo4j: Este es un nodo moderno y muy recomendable que incluye soporte para LangChain, búsqueda de similitud vectorial y operaciones de grafos como Create Node y Execute Query. Sus características se alinean perfectamente con los flujos de trabajo del usuario, como unified-rag-workflow.json y git-repository-ingestion.json.8
* @rxap/n8n-nodes-neo4j: Una opción más básica pero funcional, que también incluye su propio tipo de credencial para la conexión.9
* penrose.dev/n8n-nodes-neo4j-extended: Este es un nodo avanzado con potentes capacidades de análisis de consultas, métricas de rendimiento y modos de depuración. Podría ser de un valor incalculable para el flujo de trabajo query-pattern-optimizer.json.10
Instalación y Configuración Superior de Credenciales:
La instalación de nodos comunitarios en una instancia autoalojada de n8n se realiza típicamente añadiendo el nombre del paquete a la variable de entorno NODE_FUNCTION_ALLOW_EXTERNAL en el archivo docker-compose.yml.19
Una vez instalado un nodo como @Kurea/n8n-nodes-neo4j, el proceso de configuración de credenciales mejora drásticamente:
1. Aparecerá un nuevo tipo de credencial Neo4j en la lista.
2. El formulario de la credencial solicitará todos los parámetros de conexión necesarios en un único lugar: Connection URI (ej. neo4j://neo4j-db:7687), Username, Password y Database.8
3. Esta co-ubicación de todos los ajustes de conexión no solo simplifica la configuración, sino que también facilita la gestión, ya que la URL del host, que puede variar entre entornos (desarrollo/producción), se almacena de forma segura junto con las credenciales.
La existencia de múltiples nodos comunitarios para Neo4j, ricos en características, es una fuerte señal de que la interacción directa con la API HTTP es un antipatrón para este caso de uso. La comunidad ha "votado" eficazmente por una abstracción de más alto nivel. Los nodos dedicados ofrecen características como la parametrización nativa de Cypher, la integración de búsqueda vectorial y el análisis de consultas, que son imposibles o muy complejas de lograr con el nodo genérico HTTP Request y que se alinean directamente con las necesidades avanzadas del usuario.


Tabla 1: Comparativa de Métodos de Conexión a Neo4j




Característica
	Acceso Directo vía Nodo HTTP
	Nodo Comunitario Neo4j
	Facilidad de Configuración
	Moderada. Requiere configurar credencial y URL por separado.
	Alta. Todos los parámetros de conexión en una única credencial.
	Ejecución de Consultas Cypher
	Manual. Requiere construir JSON complejo y propenso a errores.
	Nativa. Campo dedicado para Cypher con resaltado de sintaxis.
	Manejo de Parámetros
	Complejo. Requiere inyección manual en la cadena JSON.
	Sencillo. Soporte nativo para pasar parámetros de forma segura.
	Soporte de Búsqueda Vectorial
	No soportado directamente.
	Soportado (ej. @Kurea/n8n-nodes-neo4j).
	Análisis de Consultas
	No soportado.
	Soportado (ej. n8n-nodes-neo4j-extended).
	Mantenibilidad
	Baja. Acoplamiento fuerte a la API HTTP.
	Alta. Abstracción de la API, más resistente a cambios.
	Recomendación General
	No recomendado para producción.
	Altamente recomendado para cualquier uso.
	________________


Parte 3: Asegurando la API del DataLive Agent: La Capa de Procesamiento de IA


Esta sección aborda la brecha de seguridad crítica identificada en la especificación del servicio personalizado del usuario y proporciona una ruta de implementación clara y segura.


3.1 De "None" a Seguro: Cerrando la Brecha de Autenticación


La especificación del usuario de httpRequestAuth + none para el DataLive Agent es una bandera roja de seguridad. Si bien esta configuración es aceptable para el desarrollo en un entorno local donde la red es completamente confiable, constituye una vulnerabilidad crítica en cualquier otro escenario, incluyendo preproducción y producción.
El modelo de amenaza es claro: una API sin autenticación está expuesta a accesos no autorizados que pueden llevar a un abuso de recursos (costosos ciclos de procesamiento de IA), la exfiltración de datos sensibles procesados por el agente o ataques de denegación de servicio que podrían paralizar una parte vital de la arquitectura. El objetivo es implementar un mecanismo de autenticación simple y robusto utilizando una clave de API estática, que es el estándar de la industria para la comunicación segura de máquina a máquina.


3.2 La Solución Estándar: Clave de API vía Autenticación de Cabecera


El método más común y directo para asegurar una API interna es la autenticación por cabecera. El cliente (n8n) presenta un token secreto en una cabecera de la solicitud HTTP, y el servidor (DataLive Agent) la valida antes de procesar la petición.
Configuración Paso a Paso:
1. Generar una Clave Segura: El primer paso es generar una cadena de caracteres aleatoria y criptográficamente segura para que actúe como clave de API.
2. Crear la Credencial en n8n:
   * Navegar a Credentials > New.
   * Buscar y seleccionar el tipo Header Auth.
   * Asignar un nombre, como DataLive-Agent-Header-Auth.
   * En el campo Name, introducir el nombre de la cabecera. Nombres comunes son X-API-Key o Authorization.
   * En el campo Value, introducir la clave de API secreta. Si se utiliza la cabecera Authorization, el valor debe ir precedido por el esquema Bearer , por ejemplo: Bearer sk-xxxxxxxxxxxxxx.3
   * Guardar la credencial.
3. Aplicar la Credencial en el Nodo HTTP Request:
   * En los nodos que llaman al DataLive Agent, establecer Authentication en Generic Credential Type.
   * Establecer Generic Auth Type en Header Auth.
   * Seleccionar la credencial DataLive-Agent-Header-Auth recién creada.
4. Implementación en el Servidor: Es fundamental actualizar el código de la aplicación DataLive Agent para que espere esta cabecera, extraiga la clave y la valide. Cualquier solicitud que no contenga una clave válida debe ser rechazada con un código de estado HTTP 401 Unauthorized o 403 Forbidden.


3.3 Escenario Avanzado: Múltiples Cabeceras Secretas con Custom Auth


Algunas APIs pueden requerir múltiples valores secretos en las cabeceras para la autenticación. La credencial estándar Header Auth solo admite un único par nombre-valor.3 Para estos casos, n8n proporciona el tipo de credencial
Custom Auth.
Esta credencial permite definir un objeto JSON que se inyecta en la solicitud, ofreciendo máxima flexibilidad. Por ejemplo, si una API requiriera una clave y un identificador de solicitante, se podría configurar de la siguiente manera dentro de la credencial Custom Auth 3:


JSON




{
 "headers": {
   "X-API-KEY": "{{$credentials.apiKey}}",
   "X-Requested-By": "{{$credentials.requestorId}}"
 }
}

En este caso, la credencial Custom Auth tendría dos campos definidos: apiKey y requestorId, cuyos valores se inyectarían de forma segura en las cabeceras correspondientes.
La especificación auth: none no es solo una característica ausente, sino un indicador de una mentalidad de "desarrollar primero, asegurar después". Este informe busca cambiar esa perspectiva, enmarcando la seguridad no como un añadido posterior, sino como una parte integral del ciclo de vida del desarrollo. Al explicar el modelo de amenaza y posicionar la solución como un paso hacia la "madurez" de la API, se proporciona no solo una solución técnica, sino también una valiosa lección sobre prácticas de desarrollo de software seguro.
________________


Parte 4: Manual Integral de Solución de Problemas


Esta sección es una guía pragmática y accionable para resolver los problemas más comunes y frustrantes que pueden surgir al conectar los componentes de esta arquitectura, especialmente en entornos contenerizados.


4.1 Errores de Red y Conexión (La Pesadilla del ECONNREFUSED)


El error ECONNREFUSED es uno de los más comunes y confusos en entornos Docker. Indica que la conexión fue activamente rechazada por el destino. Esto no significa que el host sea inalcanzable, sino que no hay ningún servicio escuchando en el puerto de destino o que algo está bloqueando la conexión.20
La Trampa de localhost en Contenedores:
El concepto más crítico a comprender es que, desde dentro de un contenedor (por ejemplo, el de n8n), localhost o 127.0.0.1 se refieren al propio contenedor de n8n, no a la máquina anfitriona ni a otros contenedores.21 Por lo tanto, intentar conectar a una URL como
http://localhost:7687 para alcanzar un servicio Neo4j que se ejecuta en otro contenedor o en la máquina anfitriona está destinado a fallar.


Tabla 2: Solución de Errores ECONNREFUSED en Entornos Docker




Ubicación de n8n
	Ubicación del Servicio de Destino
	Hostname a Utilizar en n8n
	Explicación
	Contenedor
	Otro contenedor (mismo docker-compose)
	http://<nombre_del_servicio>:<puerto>
	Los servicios en la misma red Docker pueden comunicarse entre sí utilizando sus nombres de servicio como si fueran DNS.
	Contenedor
	Máquina anfitriona (fuera de Docker)
	http://host.docker.internal:<puerto>
	host.docker.internal es un nombre DNS especial que se resuelve a la IP interna de la máquina anfitriona desde dentro de un contenedor Docker.
	Local (sin Docker)
	Local (sin Docker)
	http://localhost:<puerto>
	Ambos servicios se ejecutan en la misma máquina, por lo que localhost funciona como se espera.
	n8n Cloud
	Local (máquina de desarrollo)
	No recomendado para producción.
	Exponer un servicio local a Internet es un riesgo de seguridad. Utilizar un servicio de túnel (ej. ngrok) solo para pruebas temporales.
	Lista de Verificación para Diagnóstico Sistemático:
1. Verificar que el Servicio Esté en Ejecución: Usar docker ps para confirmar que los contenedores de Neo4j y DataLive Agent están activos.
2. Revisar Mapeo de Puertos: En el archivo docker-compose.yml, asegurarse de que los puertos internos de los servicios están correctamente mapeados a los puertos del host (ej. ports: - "7687:7687").
3. Usar docker exec para Pruebas Internas: Obtener una terminal dentro del contenedor de n8n (docker exec -it <n8n_container_name> /bin/sh) y usar herramientas como ping o nc (netcat) para probar la conectividad con el otro servicio por su nombre de servicio (ej. ping neo4j-db). Esta es la prueba definitiva de visibilidad de red dentro de Docker.22
4. Comprobar Firewalls: Revisar los firewalls a nivel de host (como ufw en Linux o el Firewall de Windows Defender) que podrían estar bloqueando el tráfico en los puertos necesarios.


4.2 Errores de Autenticación y Autorización (HTTP 401/403)


El error "Forbidden - perhaps check your credentials" indica que la autenticación falló.23
* Causas Comunes: Errores tipográficos en claves o contraseñas, credenciales incorrectas, tokens expirados, permisos o ámbitos insuficientes en la clave de API (ej. la clave es de solo lectura pero el flujo de trabajo intenta escribir), o listas blancas de IP en el servicio de destino que no incluyen la IP de n8n.
* Diagnóstico de Cabeceras de Autorización Perdidas: Se han reportado problemas en algunas versiones de n8n o con ciertos tipos de credenciales donde la cabecera Authorization no se envía correctamente.24
   * Solución Alternativa: Si un tipo de credencial genérica parece estar fallando, una alternativa fiable es configurar Authentication: None en el nodo y especificar manualmente la cabecera Authorization en la sección "Headers". Aunque menos ideal, es una forma pragmática de eludir posibles errores del nodo.
   * Nodos Obsoletos: El uso de nodos obsoletos puede provocar que la autenticación falle silenciosamente. Es crucial asegurarse de que se están utilizando las últimas versiones de los nodos disponibles.26


4.3 Errores de Solicitud y Datos (HTTP 400/429)


* Depuración de "Bad Request" (400): Este error significa que el servidor de destino considera que la solicitud está malformada.23
   * Validar JSON: Copiar el cuerpo JSON del nodo de n8n y pegarlo en un validador de JSON externo para encontrar errores de sintaxis.
   * Consultar la Documentación de la API: La única fuente de verdad para un error 400 es la documentación de la API de destino.
* Manejo Resiliente de Límites de Tasa (429): Este error indica que se ha excedido el número de solicitudes permitidas en un período de tiempo.23
   * Herramientas Integradas de n8n: El nodo HTTP Request tiene opciones integradas para manejar esto. En la pestaña Options, se pueden configurar:
      * Batching (Procesamiento por Lotes): Permite agrupar elementos y establecer un intervalo entre lotes. Por ejemplo, para una API con un límite de 60 solicitudes por minuto, se puede establecer Batch Interval (ms) en 1000 para asegurar un máximo de una solicitud por segundo.
      * Retry on Fail (Reintentar en caso de fallo): En la pestaña Settings, se puede habilitar esta opción para que n8n reintente automáticamente la solicitud después de un tiempo de espera configurable.
   * Ubicación Estratégica: Estas configuraciones deben aplicarse a los nodos que realizan llamadas a la API dentro de bucles, que es donde es más probable que se excedan los límites de tasa.
________________


Conclusión y Recomendaciones Estratégicas


La arquitectura propuesta es potente y tiene el potencial de ofrecer un valor inmenso al centralizar y automatizar el acceso al conocimiento organizacional. Para transformar este sistema de un prototipo avanzado a una plataforma de producción robusta, segura y escalable, se presentan las siguientes recomendaciones clave:
1. Arquitectura para la Mantenibilidad: Se recomienda encarecidamente adoptar un nodo comunitario dedicado para Neo4j, como @Kurea/n8n-nodes-neo4j. Esto abstraerá la complejidad de la API, mejorará la mantenibilidad y desbloqueará características avanzadas como la búsqueda vectorial, que son cruciales para los casos de uso de RAG descritos.
2. Seguridad por Defecto: Es imperativo implementar de inmediato la autenticación por cabecera (Header Auth) para el DataLive Agent. La configuración auth: none debe ser tratada como una vulnerabilidad crítica a ser parcheada antes de cualquier despliegue fuera de un entorno de desarrollo local aislado.
3. Externalización Completa de la Configuración: Para un sistema listo para producción, todos los secretos (claves de API, contraseñas) y valores específicos del entorno (nombres de host, URLs) deben ser eliminados de la definición del flujo de trabajo. Deben gestionarse a través de variables de entorno, preferiblemente utilizando el sufijo _FILE en conjunto con un sistema de gestión de secretos como Docker Secrets o Kubernetes Secrets.
4. Resolución Sistemática de Problemas: Es fundamental comprender la naturaleza de la red en un entorno contenerizado para diagnosticar problemas de manera eficiente. Se debe adoptar un enfoque metódico, comenzando por verificar la conectividad de la red básica entre contenedores antes de investigar problemas de autenticación o de la aplicación.
La implementación de estas recomendaciones elevará la arquitectura actual, asegurando que no solo sea funcionalmente impresionante, sino también operativamente sólida y segura para el futuro.
Works cited
1. Credentials files - n8n Docs, accessed July 2, 2025, https://docs.n8n.io/integrations/creating-nodes/build/reference/credentials-files/
2. Credentials - n8n Docs, accessed July 2, 2025, https://docs.n8n.io/credentials/
3. HTTP Request Node - Header Auth - How to securely save Credentials - n8n Community, accessed July 2, 2025, https://community.n8n.io/t/http-request-node-header-auth-how-to-securely-save-credentials/42402
4. AWS credentials - n8n Docs, accessed July 2, 2025, https://docs.n8n.io/integrations/builtin/credentials/aws/
5. Google credentials - n8n Docs, accessed July 2, 2025, https://docs.n8n.io/integrations/builtin/credentials/google/
6. ServiceNow credentials - n8n Docs, accessed July 2, 2025, https://docs.n8n.io/integrations/builtin/credentials/servicenow/
7. HTTP Request credentials - n8n Docs, accessed July 2, 2025, https://docs.n8n.io/integrations/builtin/credentials/httprequest/
8. N8N node to work with your data in Neo4j Vector Store - GitHub, accessed July 2, 2025, https://github.com/Kurea/n8n-nodes-neo4j
9. @rxap/n8n-nodes-neo4j - npm, accessed July 2, 2025, https://npmjs.com/package/@rxap/n8n-nodes-neo4j?ref=pkgstats.com
10. n8n-nodes-neo4j-extended - penrose.dev - GitLab, accessed July 2, 2025, https://gitlab.com/penrose.dev/n8n-nodes-neo4j-extended
11. n8n-nodes-neo4jtool CDN by jsDelivr - A CDN for npm and GitHub, accessed July 2, 2025, https://www.jsdelivr.com/package/npm/n8n-nodes-neo4jtool
12. Credentials environment variables | n8n Docs, accessed July 2, 2025, https://docs.n8n.io/hosting/configuration/environment-variables/credentials/
13. Environment Variables Overview - n8n Docs, accessed July 2, 2025, https://docs.n8n.io/hosting/configuration/environment-variables/
14. n8n Environment Variables: What They Are and How to Use Them - YouTube, accessed July 2, 2025, https://m.youtube.com/watch?v=sOLvmMqk9ME&t=76s
15. Security environment variables | n8n Docs, accessed July 2, 2025, https://docs.n8n.io/hosting/configuration/environment-variables/security/
16. Database environment variables - n8n Docs, accessed July 2, 2025, https://docs.n8n.io/hosting/configuration/environment-variables/database/
17. n8n/packages/nodes-base/credentials/HttpBasicAuth.credentials.ts at master - GitHub, accessed July 2, 2025, https://github.com/n8n-io/n8n/blob/master/packages/nodes-base/credentials/HttpBasicAuth.credentials.ts
18. Support Neo4j database - Feature Requests - n8n Community, accessed July 2, 2025, https://community.n8n.io/t/support-neo4j-database/48327
19. Install and manage community nodes - n8n Docs, accessed July 2, 2025, https://docs.n8n.io/integrations/community-nodes/installation/
20. I am getting this "ERROR: connect ECONNREFUSED ::1:465" - Questions - n8n Community, accessed July 2, 2025, https://community.n8n.io/t/i-am-getting-this-error-connect-econnrefused-465/9915
21. node.js - Unable to connect to neo4j from nodejs using neo4j driver ..., accessed July 2, 2025, https://stackoverflow.com/questions/64831589/unable-to-connect-to-neo4j-from-nodejs-using-neo4j-driver
22. Unable to Connect n8n to Local Ollama Instance ... - n8n Community, accessed July 2, 2025, https://community.n8n.io/t/unable-to-connect-n8n-to-local-ollama-instance-econnrefused-error/90508
23. HTTP Request node common issues | n8n Docs, accessed July 2, 2025, https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/common-issues/
24. HTTP Request node - Generic Credential with Bearer Auth doesn't add Authorization header, causing 401 error · Issue #14884 · n8n-io/n8n - GitHub, accessed July 2, 2025, https://github.com/n8n-io/n8n/issues/14884
25. HTTP Request Module Not Passing Authentication - Questions - n8n Community, accessed July 2, 2025, https://community.n8n.io/t/http-request-module-not-passing-authentication/112255
26. Authorization headers are not passed through correctly on n8n (both Bearer and Custom), accessed July 2, 2025, https://community.n8n.io/t/authorization-headers-are-not-passed-through-correctly-on-n8n-both-bearer-and-custom/117484
27. N8n HTTP Request Failing Due to Rate Limits – Possible Solutions? - Questions, accessed July 2, 2025, https://community.n8n.io/t/n8n-http-request-failing-due-to-rate-limits-possible-solutions/82750