// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ArtistRegistry is Ownable(msg.sender) {
    // Mapping des artistes vérifiés
    mapping(address => bool) private verifiedArtists;
    // Liste des artistes enregistrés pour itération
    address[] public verifiedArtistsList;

    // Événements
    event ArtistVerified(address indexed artist);
    event ArtistRemoved(address indexed artist);

    /**
     * @dev Initialise le contrat avec un propriétaire qui gère les artistes.
     */
    constructor(address _admin) {
        require(_admin != address(0), "Admin address cannot be zero");
        _transferOwnership(_admin); // Définit l'owner via OpenZeppelin Ownable
    }

    /**
     * @notice Ajoute un artiste à la liste des artistes vérifiés.
     * @param _artist Adresse de l'artiste.
     */
    function verifyArtist(address _artist) external onlyOwner {
        require(_artist != address(0), "Invalid artist address");
        require(!verifiedArtists[_artist], "Artist already verified");

        verifiedArtists[_artist] = true;
        verifiedArtistsList.push(_artist); // Ajouter à la liste

        emit ArtistVerified(_artist);
    }

    /**
     * @notice Supprime un artiste de la liste des artistes vérifiés.
     * @param _artist Adresse de l'artiste.
     */
    function removeArtist(address _artist) external onlyOwner {
        require(verifiedArtists[_artist], "Artist not found");

        verifiedArtists[_artist] = false; // Désactive l'artiste mais conserve son historique
        emit ArtistRemoved(_artist);
    }



}




