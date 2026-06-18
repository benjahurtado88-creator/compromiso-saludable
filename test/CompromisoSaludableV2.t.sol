// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {CompromisoSaludableV2} from "../src/CompromisoSaludableV2.sol";

contract CompromisoSaludableV2Test is Test {
    CompromisoSaludableV2 c;

    address validador = address(this); // el que despliega es el validador
    address ana = makeAddr("ana");
    address ben = makeAddr("ben");
    address caro = makeAddr("caro");

    uint256 constant DEP = 1 ether;

    function setUp() public {
        c = new CompromisoSaludableV2();
        // Le damos saldo a los participantes para que puedan depositar.
        vm.deal(ana, 10 ether);
        vm.deal(ben, 10 ether);
        vm.deal(caro, 10 ether);
    }

    // Inscribe a un usuario en el desafío 0 con el depósito estándar.
    function _inscribir(address quien) internal {
        vm.prank(quien);
        c.inscribirse{value: DEP}(0);
    }

    function test_CrearDesafio() public {
        uint256 id = c.crearDesafio("Correr 3 veces", DEP, 7);
        (, uint256 deposito,,,,,) = c.obtenerDesafio(id);
        assertEq(id, 0);
        assertEq(deposito, DEP);
        assertEq(c.totalDesafios(), 1);
    }

    function test_InscripcionRequiereMontoExacto() public {
        c.crearDesafio("Correr 3 veces", DEP, 7);
        vm.prank(ana);
        vm.expectRevert(bytes("Debes depositar el monto exacto"));
        c.inscribirse{value: 0.5 ether}(0);
    }

    // ⭐ El test clave: 2 ganadores y 1 perdedor.
    // El pozo (1 ETH del perdedor) se reparte: 0.5 ETH para cada ganador.
    // Cada ganador retira 1 ETH (su depósito) + 0.5 ETH (parte) = 1.5 ETH.
    function test_RepartoEntreGanadores() public {
        c.crearDesafio("Correr 3 veces", DEP, 7);
        _inscribir(ana);
        _inscribir(ben);
        _inscribir(caro);

        c.validar(0, ana, true); // ana cumple
        c.validar(0, ben, true); // ben cumple
        c.validar(0, caro, false); // caro falla -> su 1 ETH va al pozo
        c.cerrarDesafio(0);

        (,,,,, uint256 ganadores, uint256 pozo) = c.obtenerDesafio(0);
        assertEq(ganadores, 2);
        assertEq(pozo, 1 ether);

        // premioDe debe anticipar 1.5 ETH para un ganador.
        assertEq(c.premioDe(0, ana), 1.5 ether);

        uint256 antes = ana.balance;
        vm.prank(ana);
        c.reclamar(0);
        assertEq(ana.balance - antes, 1.5 ether); // recuperó depósito + parte del pozo

        uint256 antesBen = ben.balance;
        vm.prank(ben);
        c.reclamar(0);
        assertEq(ben.balance - antesBen, 1.5 ether);
    }

    function test_PerdedorNoPuedeReclamar() public {
        c.crearDesafio("Correr 3 veces", DEP, 7);
        _inscribir(ana);
        _inscribir(caro);
        c.validar(0, ana, true);
        c.validar(0, caro, false);
        c.cerrarDesafio(0);

        vm.prank(caro);
        vm.expectRevert(bytes("No ganaste o ya reclamaste"));
        c.reclamar(0);
    }

    function test_NoReclamarDosVeces() public {
        c.crearDesafio("Correr 3 veces", DEP, 7);
        _inscribir(ana);
        _inscribir(caro);
        c.validar(0, ana, true);
        c.validar(0, caro, false);
        c.cerrarDesafio(0);

        vm.prank(ana);
        c.reclamar(0);

        vm.prank(ana);
        vm.expectRevert(bytes("No ganaste o ya reclamaste"));
        c.reclamar(0);
    }

    function test_SoloValidadorValida() public {
        c.crearDesafio("Correr 3 veces", DEP, 7);
        _inscribir(ana);
        vm.prank(ben);
        vm.expectRevert(bytes("Solo el validador puede hacer esto"));
        c.validar(0, ana, true);
    }

    function test_NoReclamarAntesDeCerrar() public {
        c.crearDesafio("Correr 3 veces", DEP, 7);
        _inscribir(ana);
        c.validar(0, ana, true);
        // sin cerrarDesafio todavía
        vm.prank(ana);
        vm.expectRevert(bytes("El desafio aun no se cierra"));
        c.reclamar(0);
    }

    // Si nadie cumple, el validador rescata el pozo para que no quede atrapado.
    function test_RescatarPozoSiNadieGana() public {
        c.crearDesafio("Correr 3 veces", DEP, 7);
        _inscribir(ana);
        _inscribir(caro);
        c.validar(0, ana, false);
        c.validar(0, caro, false);
        c.cerrarDesafio(0);

        address causa = makeAddr("causa");
        c.rescatarPozo(0, causa);
        assertEq(causa.balance, 2 ether); // los dos depósitos
    }

    // Si hay ganadores, NO se puede rescatar el pozo (les toca a ellos).
    function test_NoRescatarSiHayGanadores() public {
        c.crearDesafio("Correr 3 veces", DEP, 7);
        _inscribir(ana);
        _inscribir(caro);
        c.validar(0, ana, true);
        c.validar(0, caro, false);
        c.cerrarDesafio(0);

        address causa = makeAddr("causa");
        vm.expectRevert(bytes("Hay ganadores: les toca a ellos"));
        c.rescatarPozo(0, causa);
    }
}
