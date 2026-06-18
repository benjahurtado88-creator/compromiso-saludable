// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Importamos la "caja de herramientas" de pruebas de Foundry...
import {Test} from "forge-std/Test.sol";
// ...y el contrato que vamos a probar.
import {CompromisoSaludable} from "../src/CompromisoSaludable.sol";

/// @notice Pruebas automáticas del contrato CompromisoSaludable.
/// @dev    Cada función que empieza con "test" es una prueba independiente.
///         Foundry crea un contrato nuevo y limpio antes de cada una.
contract CompromisoSaludableTest is Test {
    CompromisoSaludable internal contrato;

    // Creamos dos "personajes" de prueba con direcciones inventadas.
    address internal validador = address(this); // el que despliega = dueño
    address internal ana = makeAddr("ana"); // una usuaria de prueba

    /// @notice setUp() se ejecuta ANTES de cada test, para partir de cero.
    function setUp() public {
        contrato = new CompromisoSaludable(); // lo despliega este contrato de test
        vm.deal(ana, 10 ether); // le regalamos 10 ETH de prueba a Ana
    }

    /// @notice Crear un compromiso debe guardar bien los datos.
    function test_CrearCompromiso() public {
        vm.prank(ana); // la próxima llamada la hace "Ana"
        uint256 id = contrato.crearCompromiso{value: 1 ether}("Meditar 10 dias", 10);

        (address usuario, string memory meta, uint256 deposito,, CompromisoSaludable.Estado estado) =
            contrato.obtenerCompromiso(id);

        assertEq(usuario, ana); // el dueño del compromiso es Ana
        assertEq(meta, "Meditar 10 dias"); // la meta quedó guardada
        assertEq(deposito, 1 ether); // el depósito es 1 ETH
        assertEq(uint256(estado), 0); // estado 0 = Activo
        assertEq(contrato.totalCompromisos(), 1);
    }

    /// @notice Flujo feliz: Ana cumple, valida el dueño, Ana recupera su depósito.
    function test_FlujoCumplido() public {
        vm.prank(ana);
        uint256 id = contrato.crearCompromiso{value: 1 ether}("Correr 3 veces", 7);

        // El validador (este contrato de test) confirma que cumplió.
        contrato.validar(id, true);

        uint256 saldoAntes = ana.balance;
        vm.prank(ana);
        contrato.reclamar(id);

        // Ana debe haber recuperado exactamente su 1 ETH.
        assertEq(ana.balance, saldoAntes + 1 ether);
    }

    /// @notice Si no cumple, el depósito va al pozo y NO puede reclamar.
    function test_FlujoFallido() public {
        vm.prank(ana);
        uint256 id = contrato.crearCompromiso{value: 1 ether}("Dormir 8h", 5);

        contrato.validar(id, false); // no cumplió

        assertEq(contrato.pozoSolidario(), 1 ether); // su depósito quedó en el pozo

        // Si intenta reclamar, debe revertir (fallar) con nuestro mensaje.
        vm.prank(ana);
        vm.expectRevert("No esta cumplido o ya lo reclamaste");
        contrato.reclamar(id);
    }

    /// @notice Solo el validador puede validar; otro usuario no.
    function test_SoloValidadorValida() public {
        vm.prank(ana);
        uint256 id = contrato.crearCompromiso{value: 1 ether}("Tomar agua", 3);

        // Ana (que no es el dueño) intenta validar -> debe revertir.
        vm.prank(ana);
        vm.expectRevert("Solo el validador puede hacer esto");
        contrato.validar(id, true);
    }

    /// @notice No se puede reclamar dos veces el mismo depósito.
    function test_NoReclamarDosVeces() public {
        vm.prank(ana);
        uint256 id = contrato.crearCompromiso{value: 1 ether}("Estirar", 2);
        contrato.validar(id, true);

        vm.prank(ana);
        contrato.reclamar(id); // primer reclamo: ok

        vm.prank(ana);
        vm.expectRevert("No esta cumplido o ya lo reclamaste");
        contrato.reclamar(id); // segundo reclamo: debe fallar
    }
}
