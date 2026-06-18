// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title  Compromiso Saludable V2 — con reparto del pozo
/// @notice Versión 2: el dinero de los que NO cumplen se reparte
///         automáticamente entre los que SÍ cumplieron.
/// @dev    A diferencia de la V1 (compromisos individuales), acá la gente
///         se inscribe en un "desafío" grupal con un depósito fijo. Al cerrar
///         el desafío, cada ganador recupera su depósito + una parte igual
///         del pozo formado por los depósitos de los que fallaron.
///         Pensado para un grupo de amigos / comunidad de confianza.
contract CompromisoSaludableV2 {
    // =========================================================================
    // 1) VARIABLES DE ESTADO
    // =========================================================================

    /// @notice Dueño del contrato. Es quien crea y valida los desafíos.
    address public owner;

    /// @notice Situación de cada participante dentro de un desafío.
    enum Estado {
        NoInscrito, // 0: valor por defecto = esta persona no participa
        Inscrito, // 1: depositó y espera el veredicto
        Cumplido, // 2: el validador confirmó que cumplió (es ganador)
        Fallido, // 3: no cumplió; su depósito va al pozo
        Reclamado // 4: ya retiró lo que le correspondía (evita doble retiro)
    }

    /// @notice La "ficha" de cada desafío grupal.
    struct Desafio {
        string nombre; // descripción (ej: "Correr 3 veces esta semana")
        uint256 deposito; // cuánto deposita cada participante (en wei)
        uint256 plazo; // fecha límite (timestamp de Unix)
        bool resuelto; // true cuando el validador cierra el desafío
        uint256 totalInscritos; // cuántos se inscribieron
        uint256 totalGanadores; // cuántos cumplieron
        uint256 pozoPerdedores; // suma de los depósitos de los que fallaron
    }

    /// @notice Cuántos desafíos se han creado (también es el próximo id).
    uint256 public totalDesafios;

    /// @notice Guarda cada desafío por su id. id => ficha del desafío.
    mapping(uint256 => Desafio) public desafios;

    /// @notice Estado de cada persona en cada desafío. id => (persona => estado).
    mapping(uint256 => mapping(address => Estado)) public estadoDe;

    // =========================================================================
    // 2) EVENTOS
    // =========================================================================

    event DesafioCreado(uint256 indexed id, string nombre, uint256 deposito, uint256 plazo);
    event Inscrito(uint256 indexed id, address indexed usuario);
    event Validado(uint256 indexed id, address indexed usuario, bool cumplio);
    event DesafioResuelto(uint256 indexed id, uint256 ganadores, uint256 pozo);
    event Reclamado(uint256 indexed id, address indexed usuario, uint256 monto);

    // =========================================================================
    // 3) CONSTRUCTOR
    // =========================================================================

    constructor() {
        owner = msg.sender; // quien despliega queda como dueño/validador
    }

    // =========================================================================
    // 4) MODIFICADOR
    // =========================================================================

    modifier soloValidador() {
        require(msg.sender == owner, "Solo el validador puede hacer esto");
        _;
    }

    // =========================================================================
    // 5) FUNCIONES PRINCIPALES
    // =========================================================================

    /// @notice El validador crea un desafío con un depósito fijo y un plazo.
    /// @param nombre        Descripción de la meta del desafío.
    /// @param deposito      Cuánto deberá depositar cada participante (en wei).
    /// @param duracionDias  En cuántos días vence el desafío.
    /// @return id           El número asignado a este desafío.
    function crearDesafio(string calldata nombre, uint256 deposito, uint256 duracionDias)
        external
        soloValidador
        returns (uint256 id)
    {
        require(deposito > 0, "El deposito debe ser mayor a 0");
        require(duracionDias > 0, "El plazo debe ser de al menos 1 dia");

        id = totalDesafios;
        Desafio storage d = desafios[id];
        d.nombre = nombre;
        d.deposito = deposito;
        d.plazo = block.timestamp + (duracionDias * 1 days);

        totalDesafios++;
        emit DesafioCreado(id, nombre, deposito, d.plazo);
    }

    /// @notice Te inscribes en un desafío depositando el monto exacto.
    /// @param idDesafio  El id del desafío.
    function inscribirse(uint256 idDesafio) external payable {
        Desafio storage d = desafios[idDesafio];

        require(d.deposito > 0, "Ese desafio no existe");
        require(block.timestamp < d.plazo, "La inscripcion ya cerro");
        require(!d.resuelto, "El desafio ya fue resuelto");
        require(estadoDe[idDesafio][msg.sender] == Estado.NoInscrito, "Ya estas inscrito");
        require(msg.value == d.deposito, "Debes depositar el monto exacto");

        estadoDe[idDesafio][msg.sender] = Estado.Inscrito;
        d.totalInscritos++;
        emit Inscrito(idDesafio, msg.sender);
    }

    /// @notice El validador marca si un participante cumplió o no.
    /// @param idDesafio  El id del desafío.
    /// @param usuario    La persona a validar.
    /// @param cumplio    true si cumplió, false si no.
    function validar(uint256 idDesafio, address usuario, bool cumplio) external soloValidador {
        Desafio storage d = desafios[idDesafio];
        require(!d.resuelto, "El desafio ya fue resuelto");
        require(estadoDe[idDesafio][usuario] == Estado.Inscrito, "No inscrito o ya validado");

        if (cumplio) {
            estadoDe[idDesafio][usuario] = Estado.Cumplido;
            d.totalGanadores++;
        } else {
            estadoDe[idDesafio][usuario] = Estado.Fallido;
            d.pozoPerdedores += d.deposito; // su depósito engrosa el pozo
        }

        emit Validado(idDesafio, usuario, cumplio);
    }

    /// @notice El validador cierra el desafío para habilitar los reclamos.
    /// @dev    Llamar después de validar a todos los participantes.
    /// @param idDesafio  El id del desafío.
    function cerrarDesafio(uint256 idDesafio) external soloValidador {
        Desafio storage d = desafios[idDesafio];
        require(d.deposito > 0, "Ese desafio no existe");
        require(!d.resuelto, "El desafio ya fue resuelto");

        d.resuelto = true;
        emit DesafioResuelto(idDesafio, d.totalGanadores, d.pozoPerdedores);
    }

    /// @notice Si cumpliste, retiras tu depósito + tu parte igual del pozo.
    /// @param idDesafio  El id del desafío.
    function reclamar(uint256 idDesafio) external {
        Desafio storage d = desafios[idDesafio];

        require(d.resuelto, "El desafio aun no se cierra");
        require(estadoDe[idDesafio][msg.sender] == Estado.Cumplido, "No ganaste o ya reclamaste");

        // PATRÓN SEGURO (checks-effects-interactions):
        // 1) primero cambiamos el estado, 2) recién después enviamos el ETH.
        estadoDe[idDesafio][msg.sender] = Estado.Reclamado;

        // Reparto igualitario: el pozo de los que fallaron se divide entre los
        // ganadores. totalGanadores nunca cambia tras cerrar, así que la parte
        // es la misma para todos y la suma jamás supera el pozo.
        uint256 parte = d.pozoPerdedores / d.totalGanadores;
        uint256 monto = d.deposito + parte;

        (bool exito,) = payable(msg.sender).call{value: monto}("");
        require(exito, "Fallo el envio");

        emit Reclamado(idDesafio, msg.sender, monto);
    }

    /// @notice Si NADIE cumplió, el validador rescata el pozo (ej: una causa).
    /// @dev    Solo aplica cuando el desafío está resuelto y no hubo ganadores,
    ///         para que ese dinero no quede atrapado.
    /// @param idDesafio  El id del desafío.
    /// @param destino    A dónde enviar el pozo.
    function rescatarPozo(uint256 idDesafio, address destino) external soloValidador {
        Desafio storage d = desafios[idDesafio];
        require(d.resuelto, "El desafio aun no se cierra");
        require(d.totalGanadores == 0, "Hay ganadores: les toca a ellos");
        require(destino != address(0), "Destino invalido");

        uint256 monto = d.pozoPerdedores;
        require(monto > 0, "El pozo esta vacio");

        d.pozoPerdedores = 0; // efecto antes de la interacción (patrón seguro)

        (bool exito,) = payable(destino).call{value: monto}("");
        require(exito, "Fallo el envio del pozo");

        emit Reclamado(idDesafio, destino, monto);
    }

    // =========================================================================
    // 6) FUNCIONES DE LECTURA (no cuestan gas)
    // =========================================================================

    /// @notice Devuelve los datos de un desafío.
    function obtenerDesafio(uint256 idDesafio)
        external
        view
        returns (
            string memory nombre,
            uint256 deposito,
            uint256 plazo,
            bool resuelto,
            uint256 totalInscritos,
            uint256 totalGanadores,
            uint256 pozoPerdedores
        )
    {
        Desafio storage d = desafios[idDesafio];
        return (d.nombre, d.deposito, d.plazo, d.resuelto, d.totalInscritos, d.totalGanadores, d.pozoPerdedores);
    }

    /// @notice Cuánto le tocaría reclamar a una persona si reclamara ahora.
    /// @dev    Útil para que la web muestre el premio estimado.
    function premioDe(uint256 idDesafio, address usuario) external view returns (uint256) {
        Desafio storage d = desafios[idDesafio];
        if (estadoDe[idDesafio][usuario] != Estado.Cumplido || d.totalGanadores == 0) {
            return 0;
        }
        return d.deposito + (d.pozoPerdedores / d.totalGanadores);
    }
}
