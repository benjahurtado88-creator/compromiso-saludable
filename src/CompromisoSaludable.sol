// SPDX-License-Identifier: MIT
// ^ Licencia del código. Es obligatorio declararla; "MIT" significa de uso libre.

pragma solidity ^0.8.26;

// ^ Versión del lenguaje Solidity. "^0.8.26" = "0.8.26 o superior dentro de la 0.8".
//   Desde la 0.8 el lenguaje ya protege contra desbordamientos de números (overflow),
//   así que no necesitamos librerías extra para eso.

/// @title  Compromiso Saludable
/// @notice Contrato donde un usuario "apuesta" un depósito por una meta de bienestar.
///         Si cumple la meta dentro del plazo, recupera su depósito.
///         Si no la cumple, su depósito queda en un "pozo solidario".
/// @dev    Versión 1 (base, simple y segura). El reparto del pozo entre los que
///         cumplen se agregará en la versión 2.
contract CompromisoSaludable {
    // =========================================================================
    // 1) VARIABLES DE ESTADO  (datos que el contrato guarda para siempre)
    // =========================================================================

    /// @notice Dueño del contrato. Es quien valida si las metas se cumplieron.
    address public owner;
    // "address" = una dirección de wallet (0x...). "public" hace que cualquiera
    // pueda leer este dato. Solidity crea solo una función para consultarlo.

    /// @notice Estados posibles de un compromiso.
    enum Estado {
        Activo, // 0: creado, esperando el veredicto del validador
        Cumplido, // 1: el validador confirmó que se cumplió
        Fallido, // 2: no se cumplió; el depósito pasó al pozo
        Reclamado // 3: el usuario ya retiró su depósito (evita doble retiro)
    }

    // Un "enum" es una lista de opciones con nombre. Internamente son números
    // (Activo=0, Cumplido=1, ...), pero usar nombres hace el código legible.

    /// @notice La "ficha" de cada compromiso.
    struct Compromiso {
        address usuario; // quién creó el compromiso
        string meta; // descripción de la meta (ej: "Correr 3 veces")
        uint256 deposito; // cuánto ETH depositó (en wei, la unidad mínima)
        uint256 plazo; // fecha límite, como timestamp de Unix (segundos)
        Estado estado; // en qué situación está
    }
    // Un "struct" agrupa varios datos relacionados bajo un mismo nombre,
    // como una ficha o formulario. "uint256" = número entero positivo grande.

    /// @notice Cuántos compromisos se han creado (también sirve como próximo id).
    uint256 public totalCompromisos;

    /// @notice Guarda cada compromiso por su número de id. id => ficha.
    mapping(uint256 => Compromiso) public compromisos;
    // Un "mapping" es como un diccionario: le das una llave (el id) y te
    // devuelve su valor (la ficha del compromiso).

    /// @notice Acumula los depósitos de quienes NO cumplieron su meta.
    uint256 public pozoSolidario;

    // =========================================================================
    // 2) EVENTOS  (avisos que el contrato emite cuando pasa algo importante)
    // =========================================================================
    // Los eventos quedan registrados en la blockchain y permiten que apps
    // externas (o Etherscan) "escuchen" lo que ocurre, sin costo de lectura.

    event CompromisoCreado(uint256 indexed id, address indexed usuario, string meta, uint256 deposito, uint256 plazo);
    event CompromisoValidado(uint256 indexed id, bool cumplio);
    event DepositoReclamado(uint256 indexed id, address indexed usuario, uint256 monto);
    event PozoRetirado(address indexed destino, uint256 monto);
    // "indexed" permite buscar/filtrar eventos por ese campo más fácilmente.

    // =========================================================================
    // 3) CONSTRUCTOR  (se ejecuta UNA sola vez, al desplegar el contrato)
    // =========================================================================

    constructor() {
        owner = msg.sender;
        // "msg.sender" = la dirección que está ejecutando ahora. Al desplegar,
        // es quien crea el contrato, así que queda como dueño/validador.
    }

    // =========================================================================
    // 4) MODIFICADORES  (reglas reutilizables que se ponen antes de una función)
    // =========================================================================

    /// @notice Permite ejecutar la función solo al dueño (validador).
    modifier soloValidador() {
        require(msg.sender == owner, "Solo el validador puede hacer esto");
        _;
        // El "_;" significa "aquí se ejecuta el cuerpo de la función".
        // Si el require falla, la función se cancela y revierte todo.
    }

    // =========================================================================
    // 5) FUNCIONES PRINCIPALES
    // =========================================================================

    /// @notice Crea un compromiso depositando ETH y fijando una meta y un plazo.
    /// @param meta          Descripción de la meta de bienestar.
    /// @param duracionDias  En cuántos días vence el compromiso.
    /// @return id           El número asignado a este compromiso.
    function crearCompromiso(string calldata meta, uint256 duracionDias) external payable returns (uint256 id) {
        // "payable" = esta función puede recibir ETH junto con la llamada.
        // "external" = se llama desde afuera del contrato.

        require(msg.value > 0, "Debes depositar algo de ETH");
        // "msg.value" = cuánto ETH mandaron en la llamada. Exigimos que sea > 0.
        require(duracionDias > 0, "El plazo debe ser de al menos 1 dia");

        id = totalCompromisos; // el id de este compromiso es el contador actual

        // Guardamos la ficha en el diccionario.
        compromisos[id] = Compromiso({
            usuario: msg.sender,
            meta: meta,
            deposito: msg.value,
            plazo: block.timestamp + (duracionDias * 1 days),
            // "block.timestamp" = la hora actual de la blockchain (en segundos).
            // "1 days" es una ayuda de Solidity que vale 86400 segundos.
            estado: Estado.Activo
        });

        totalCompromisos++; // aumentamos el contador para el próximo

        emit CompromisoCreado(id, msg.sender, meta, msg.value, compromisos[id].plazo);
        return id;
    }

    /// @notice El validador confirma si un compromiso se cumplió o no.
    /// @param idCompromiso  El id del compromiso a validar.
    /// @param cumplio       true si cumplió la meta, false si no.
    function validar(uint256 idCompromiso, bool cumplio) external soloValidador {
        Compromiso storage c = compromisos[idCompromiso];
        // "storage" = trabajamos sobre el dato REAL guardado (no una copia),
        // así los cambios que hagamos quedan grabados.

        require(c.usuario != address(0), "Ese compromiso no existe");
        // Si "usuario" es la dirección vacía (0x000...0), el id no existe.
        require(c.estado == Estado.Activo, "Ese compromiso ya fue resuelto");

        if (cumplio) {
            c.estado = Estado.Cumplido;
        } else {
            c.estado = Estado.Fallido;
            pozoSolidario += c.deposito; // su depósito engrosa el pozo
        }

        emit CompromisoValidado(idCompromiso, cumplio);
    }

    /// @notice Si cumpliste, retira de vuelta tu depósito.
    /// @param idCompromiso  El id de tu compromiso cumplido.
    function reclamar(uint256 idCompromiso) external {
        Compromiso storage c = compromisos[idCompromiso];

        require(msg.sender == c.usuario, "Este compromiso no es tuyo");
        require(c.estado == Estado.Cumplido, "No esta cumplido o ya lo reclamaste");

        // PATRÓN SEGURO (checks-effects-interactions):
        // 1) primero cambiamos el estado (efecto), 2) recién después enviamos ETH.
        // Así evitamos el ataque de "reentrada" y el doble retiro.
        c.estado = Estado.Reclamado;
        uint256 monto = c.deposito;

        (bool exito,) = payable(msg.sender).call{value: monto}("");
        // "call{value: ...}" es la forma recomendada de enviar ETH.
        require(exito, "Fallo el envio del deposito");

        emit DepositoReclamado(idCompromiso, msg.sender, monto);
    }

    /// @notice El validador envía el pozo solidario a un destino (ej: una causa).
    /// @param destino  Dirección que recibirá los fondos del pozo.
    /// @dev    En la versión 2, este pozo se repartirá entre los que cumplieron.
    function retirarPozo(address destino) external soloValidador {
        require(destino != address(0), "Destino invalido");
        uint256 monto = pozoSolidario;
        require(monto > 0, "El pozo esta vacio");

        pozoSolidario = 0; // efecto antes de la interacción (patrón seguro)

        (bool exito,) = payable(destino).call{value: monto}("");
        require(exito, "Fallo el envio del pozo");

        emit PozoRetirado(destino, monto);
    }

    // =========================================================================
    // 6) FUNCIÓN DE LECTURA AUXILIAR  (no cuesta gas consultarla)
    // =========================================================================

    /// @notice Devuelve todos los datos de un compromiso.
    /// @param idCompromiso  El id a consultar.
    function obtenerCompromiso(uint256 idCompromiso)
        external
        view
        returns (address usuario, string memory meta, uint256 deposito, uint256 plazo, Estado estado)
    {
        // "view" = solo lee, no modifica nada; por eso es gratis consultarla.
        Compromiso storage c = compromisos[idCompromiso];
        return (c.usuario, c.meta, c.deposito, c.plazo, c.estado);
    }
}
