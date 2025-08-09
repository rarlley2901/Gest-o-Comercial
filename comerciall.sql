-- Criação do banco	
create database comercial;
use comercial;

-- Tabela cliente
CREATE TABLE Cliente(
id_cliente INT AUTO_INCREMENT PRIMARY KEY,
nome VARCHAR (100) NOT NULL,
CPF_CNPJ VARCHAR(20) UNIQUE,
tipo ENUM('PF', 'PJ') NOT NULL,
data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
vip BOOLEAN DEFAULT FALSE
);

CREATE TABLE Produto (
    id_produto INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    preco_custo DECIMAL(10,2),
    preco_venda DECIMAL(10,2),
    estoque INT DEFAULT 0,
    categoria VARCHAR(30)
);
DELIMITER //
CREATE TRIGGER validar_preco_venda
BEFORE INSERT ON Produto
FOR EACH ROW
BEGIN
    IF NEW.preco_venda <= NEW.preco_custo THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'preco_venda deve ser maior que preco_custo';
    END IF;
END//
DELIMITER ;

-- Tabela de venda
CREATE TABLE venda (
    id_venda INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    data_venda DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('em_processo', 'finalizada', 'cancelada') DEFAULT 'em_processo',
    total_venda DECIMAL(12,2) DEFAULT 0.00,
    FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
);


-- Tabela Item_Venda
CREATE TABLE Item_Venda (
    id_item INT AUTO_INCREMENT PRIMARY KEY,
    id_venda INT NOT NULL,
    id_produto INT NOT NULL,
    quantidade INT NOT NULL CHECK (quantidade > 0),
    desconto DECIMAL(10,2) DEFAULT 0.00,
    preco_venda DECIMAL(10,2), -- Captura o preço no momento da venda
    FOREIGN KEY (id_venda) REFERENCES Venda(id_venda) ON DELETE CASCADE,
    FOREIGN KEY (id_produto) REFERENCES Produto(id_produto),
    CONSTRAINT desconto_valido CHECK (desconto < preco_venda)
);


DELIMITER //
CREATE TRIGGER update_total_venda
AFTER INSERT ON item_venda
FOR EACH ROW
BEGIN
    UPDATE venda 
    SET total_venda = (
        SELECT SUM(quantidade * (preco_venda - desconto))
        FROM item_venda
        WHERE id_venda = NEW.id_venda
    )
    WHERE id_venda = NEW.id_venda;
END//
DELIMITER ;


-- Tabela Pagamento
CREATE TABLE Pagamento (
    id_pagamento INT AUTO_INCREMENT PRIMARY KEY,
    id_venda INT NOT NULL,
    forma_pagamento ENUM('credito', 'debito', 'boleto', 'pix') NOT NULL,
    valor_pago DECIMAL(12,2) NOT NULL,
    parcelas INT DEFAULT 1,
    FOREIGN KEY (id_venda) REFERENCES Venda(id_venda)
);

-- Índices para performance
CREATE INDEX idx_venda_cliente ON Venda(id_cliente);
CREATE INDEX idx_item_produto ON Item_Venda(id_produto);

DELIMITER //
CREATE TRIGGER atualizar_estoque
AFTER INSERT ON Item_Venda
FOR EACH ROW
BEGIN
    UPDATE Produto SET estoque = estoque - NEW.quantidade
    WHERE id_produto = NEW.id_produto;
END//
DELIMITER ;

CREATE VIEW view_kpis AS
SELECT 
    c.nome AS cliente,
    COUNT(v.id_venda) AS total_compras,
    SUM(v.total_venda) AS valor_gasto,
    AVG(v.total_venda) AS ticket_medio,
    MAX(v.data_venda) AS ultima_compra
FROM Cliente c
LEFT JOIN Venda v ON c.id_cliente = v.id_cliente
WHERE v.status = 'finalizada'
GROUP BY c.id_cliente;

-- Cadastro rápido
INSERT INTO Cliente (nome, cpf_cnpj, tipo) VALUES 
('Loja ABC', '12345678000199', 'PJ'),
('Maria Souza', '98765432100', 'PF');

INSERT INTO Produto (nome, preco_custo, preco_venda, estoque) VALUES
('Notebook i7', 2500.00, 3999.00, 10),
('Mouse Sem Fio', 30.00, 79.90, 50);

-- Venda com itens
INSERT INTO Venda (id_cliente) VALUES (1);
INSERT INTO Item_Venda (id_venda, id_produto, quantidade, preco_venda) VALUES
(1, 1, 2, 3999.00), 
(1, 2, 3, 79.90);   

-- Pagamento
INSERT INTO Pagamento (id_venda, forma_pagamento, valor_pago, parcelas) VALUES
(1, 'credito', 3999.00 * 2 + 79.90 * 3, 5);

-- Inserir um cliente
INSERT INTO Cliente (nome, cpf_cnpj, tipo) VALUES 
('TecnhoMaq', '00000014757417', 'PJ'),
('Rarlley Victoria', '9870000000', 'PF');

-- Inserir produtos
INSERT INTO Produto (nome, preco_custo, preco_venda, estoque) VALUES
('Notebook i7', 2500.00, 3999.00, 10),
('Mouse Gamer', 80.00, 149.90, 50);

-- Registrar uma venda
INSERT INTO Venda (id_cliente) VALUES (1); 

-- Adicionar itens à venda
INSERT INTO Item_Venda (id_venda, id_produto, quantidade, preco_venda, desconto) VALUES
(1, 1, 2, 3999.00, 0.00), 
(1, 2, 3, 149.90, 10.00);  

SELECT 
    v.id_venda AS 'Código Venda',
    DATE_FORMAT(v.data_venda, '%d/%m/%Y') AS 'Data',
    c.nome AS 'Cliente',
    COUNT(iv.id_item) AS 'Itens',
    v.total_venda AS 'Total R$',
    v.status AS 'Status'
FROM 
    Venda v
JOIN 
    Cliente c ON v.id_cliente = c.id_cliente
LEFT JOIN 
    Item_Venda iv ON v.id_venda = iv.id_venda
GROUP BY 
    v.id_venda
ORDER BY 
    v.data_venda DESC;


SELECT 
    p.nome AS 'Produto',
    iv.quantidade AS 'Qtd',
    iv.preco_venda AS 'Preço Unit. R$',
    iv.desconto AS 'Desconto R$',
    (iv.quantidade * (iv.preco_venda - iv.desconto)) AS 'Subtotal R$'
FROM 
    Item_Venda iv
JOIN 
    Produto p ON iv.id_produto = p.id_produto
WHERE 
    iv.id_venda = 1;  
