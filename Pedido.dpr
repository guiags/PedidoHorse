program Pedido;

{$APPTYPE CONSOLE}

{$R *.res}

uses Horse, System.JSON, Data.DB, Horse.CORS, System.Classes, Horse.Jhonson, Horse.Commons, System.SysUtils, Horse.BasicAuthentication, FireDAC.Phys.FB, FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.DApt, FireDAC.Stan.Async;


var Users: TJSONArray;
  Produtos: TJSONArray;
  Produto: TJSONObject;
  FDConnection1: TFDConnection;
  FDQuery1: TFDQuery;

procedure createConnection(FDConnection1 : TFDConnection);
  begin
    FDConnection1.DriverName := 'FB';
    FDConnection1.Params.Add('Database=C:\Users\guilh\Documents\Firebird\DADOS.fdb');
    FDConnection1.Params.Add('User_Name=SYSDBA');
    FDConnection1.Params.Add('Password=masterkey');
    FDConnection1.Params.Add('Server=localhost');
    FDConnection1.Connected := True;
  end;



begin

  THorse.Use(CORS);

  THorse.Use(Jhonson);
  {THorse.Use(HorseBasicAuthentication(
    function(const AUsername, APassword: string): Boolean
    begin
      // Here inside you can access your database and validate if username and password are valid
      Result := AUsername.Equals('user') and APassword.Equals('password');
    end));}


  Users:= TJSONArray.Create;
  Produtos:= TJSONArray.Create;

  THorse.Get('/produtos',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      Preco:Double;
      JSONNumber: TJSONNumber;
    begin
        try
          FDConnection1 := TFDConnection.Create(nil);
          FDQuery1 := TFDQuery.Create(nil);
          createConnection(FDConnection1);
          FDQuery1.Connection := FDConnection1;
          FDQuery1.SQL.Text := 'SELECT * FROM PRODUTOS';
          FDQuery1.Open;
          Produtos:= TJSONArray.Create;
          FDQuery1.First;
          while not FDQuery1.Eof do
            begin
              Produto:= TJSONObject.Create;
              try
                Preco := FDQuery1.FieldByName('PRECO').AsFloat;
                JSONNumber := TJSONNumber.Create(Preco);
                //Produto:= TJSONObject.Create;
                Produto.AddPair('ID', FDQuery1.FieldByName('ID').AsString);
                Produto.AddPair('DESCRICAO', FDQuery1.FieldByName('DESCRICAO').AsString);
                Produto.AddPair('QTDESTOQUE', FDQuery1.FieldByName('QTDESTOQUE').AsString);
                //Produto.AddPair('PRECO', FDQuery1.FieldByName('PRECO').AsString);
                Produto.AddPair('PRECO', JSONNumber);
                Produtos.AddElement(Produto);
                //Produto.Free;
              except
                Produto.Free;
                raise;
              end;
              FDQuery1.Next;
             end;
        Res.Send<TJSONArray>(Produtos).Status(THTTPStatus.OK);
        finally
          FDQuery1.Free;
        end;
    end);

  THorse.Post('/produtos',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      Produto : TJSONObject;
    begin
      Produto := Req.Body<TJSONObject>.Clone as TJSONObject;
      //try
        FDConnection1 := TFDConnection.Create(nil);
        FDQuery1 := TFDQuery.Create(nil);
        createConnection(FDConnection1);
        FDQuery1.Connection := FDConnection1;
        FDQuery1.SQL.Text := 'INSERT INTO PRODUTOS (ID, DESCRICAO, PRECO, QTDESTOQUE) VALUES (:ID, :DESCRICAO, :PRECO, :QTDESTOQUE)';
        FDQuery1.ParamByName('ID').AsInteger := StrToInt(Produto.GetValue('ID').Value);
        FDQuery1.ParamByName('QTDESTOQUE').AsInteger := StrToInt(Produto.GetValue('QTDESTOQUE').Value);
        FDQuery1.ParamByName('DESCRICAO').AsString := Produto.GetValue('DESCRICAO').Value;
        FDQuery1.ParamByName('PRECO').AsFloat := StrToFloat(Produto.GetValue('PRECO').Value);
        FDQuery1.ExecSQL;
      //Users.AddElement(User);
      Res.Send<TJSONAncestor>(Produto.Clone).Status(THTTPStatus.Created);
    end);

  THorse.Delete('/produtos/:id',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      Id: integer;
    begin
      Id := Req.Params.Items['id'].ToInteger;
      //Users.Remove(Pred(Id)).Free;
      FDConnection1 := TFDConnection.Create(nil);
        FDQuery1 := TFDQuery.Create(nil);
        createConnection(FDConnection1);
        FDQuery1.Connection := FDConnection1;
        FDQuery1.SQL.Text := 'DELETE FROM PRODUTOS WHERE ID = :Id';
        FDQuery1.ParamByName('ID').AsInteger := Id;
        FDQuery1.ExecSQL;
      Res.Send('Produto excluído com sucesso!').Status(THTTPStatus.NoContent);
    end);


    THorse.Post('/pedido', procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
      Pedido: TJSONObject;
      Query: TFDQuery;
      PedidoID: Integer;
      Item: TJSONObject;
      Itens: TJSONArray;
      i: Integer;
      begin
        //Execução do comando de obteenção do ultimo Id do pedido
        FDConnection1 := TFDConnection.Create(nil);
        Query := TFDQuery.Create(nil);
          try
            createConnection(FDConnection1);
            Query.Connection := FDConnection1;
            Query.SQL.Text := 'SELECT MAX(ID_PED) FROM PEDIDO';
            Query.Open;
            PedidoID := Query.Fields[0].AsInteger + 1;
          finally
            Query.Free;
          end;
        // Criação do registro do Pedido
        Pedido := Req.Body<TJSONObject>;
        FDConnection1 := TFDConnection.Create(nil);
        Query := TFDQuery.Create(nil);
        try
          createConnection(FDConnection1);
          Query.Connection := FDConnection1;
          Query.SQL.Text := 'INSERT INTO PEDIDO (ID_CLI, DATA_HORA, PRECO_PEDIDO, ID_PED) VALUES (:ID_CLI, :DATA_HORA, :PRECO_PEDIDO, :ID_PED) '; //+
                            //'RETURNING ID_PED';
          Query.ParamByName('ID_CLI').Asinteger := StrToInt(Pedido.GetValue('ID_CLI').Value);
          Query.ParamByName('ID_PED').Asinteger := PedidoID;
          Query.ParamByName('DATA_HORA').AsDate := Now;
          Query.ParamByName('PRECO_PEDIDO').AsFloat := StrToFloat(Pedido.GetValue('PRECO_PEDIDO').Value);
          Query.ExecSQL;
        finally
          Query.Free;
        end;

        Itens := Pedido.GetValue('itens') as TJSONArray;
      for i := 0 to Itens.Count - 1 do
        begin
          Item := Itens.Items[i] as TJSONObject;
          Query := TFDQuery.Create(nil);
          try
            Query.Connection := FDConnection1;
            Query.SQL.Text := 'INSERT INTO IT_PEDIDOS (ID_PEDIDO, ID_PRODUTO, QUANTIDADE, SEQ_PED) ' +
                              'VALUES (:ID_PEDIDO, :ID_PRODUTO, :QUANTIDADE, :SEQ_PED)';
            Query.ParamByName('SEQ_PED').AsInteger := i;
            Query.ParamByName('ID_PEDIDO').AsInteger := PedidoID;
            Query.ParamByName('ID_PRODUTO').AsInteger:= StrToInt(Item.GetValue('ID_PRODUTO').Value);
            Query.ParamByName('QUANTIDADE').AsInteger := StrToInt(Item.GetValue('QUANTIDADE').Value);
            Query.ExecSQL;
          finally
            Query.Free;
          end;
        end;
      Res.Send('Pedido criado com sucesso!').Status(THTTPStatus.OK);

      end);


      THorse.Get('/pedido', procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
      Pedido: TJSONObject;
      Pedidos: TJSONArray;
      Query: TFDQuery;
      Query2: TFDQuery;
      FDConnection2: TFDConnection;
      begin
        FDConnection1 := TFDConnection.Create(nil);
        Query := TFDQuery.Create(nil);
          try
            createConnection(FDConnection1);
            Query.Connection := FDConnection1;
            Query.SQL.Text := 'SELECT * FROM PEDIDO';
            Query.Open;

            Pedidos:= TJSONArray.Create;
            Query.First;
          while not Query.Eof do
            begin
              Pedido:= TJSONObject.Create;
              try
              FDConnection2 := TFDConnection.Create(nil);
              Query2 := TFDQuery.Create(nil);
              createConnection(FDConnection2);
              Query2.Connection := FDConnection2;
              Query2.SQL.Text := 'SELECT NOME FROM CLIENTES WHERE ID = :ID';
              Query2.ParamByName('ID').AsString := Query.FieldByName('ID_CLI').AsString;
              Query2.Open;
                Pedido.AddPair('ID_PED', Query.FieldByName('ID_PED').AsString);
                Pedido.AddPair('ID_CLI', Query.FieldByName('ID_CLI').AsString);
                Pedido.AddPair('NOME_CLIENTE', Query2.FieldByName('NOME').AsString);
                Pedido.AddPair('DATA_HORA', Query.FieldByName('DATA_HORA').AsString);
                Pedido.AddPair('PRECO_PEDIDO', Query.FieldByName('PRECO_PEDIDO').AsString);
                Pedidos.AddElement(Pedido);
              except
                Pedido.Free;
                raise;
              end;
              Query.Next;
             end;
          Res.Send<TJSONArray>(Pedidos).Status(THTTPStatus.OK);
          finally
            Query.Free;
          end;
      end);


      THorse.Get('/itpedido/:id', procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
      Pedido: TJSONObject;
      Pedidos: TJSONArray;
      Query: TFDQuery;
      Query2: TFDQuery;
      FDConnection2: TFDConnection;
      begin
        FDConnection1 := TFDConnection.Create(nil);
        Query := TFDQuery.Create(nil);
          try
            createConnection(FDConnection1);
            Query.Connection := FDConnection1;
            Query.SQL.Text := 'SELECT * FROM IT_PEDIDOS WHERE ID_PEDIDO = :ID_PEDIDO';
            Query.ParamByName('ID_PEDIDO').AsString := Req.Params.Items['id'];
            Query.Open;

            Pedidos:= TJSONArray.Create;
            Query.First;
          while not Query.Eof do
            begin
              Pedido:= TJSONObject.Create;
              try

                FDConnection2 := TFDConnection.Create(nil);
                Query2 := TFDQuery.Create(nil);
                createConnection(FDConnection2);
                Query2.Connection := FDConnection2;
                Query2.SQL.Text := 'SELECT DESCRICAO, PRECO FROM PRODUTOS WHERE ID = :ID';
                Query2.ParamByName('ID').AsString := Query.FieldByName('ID_PRODUTO').AsString;
                Query2.Open;

                Pedido.AddPair('ID_PEDIDO', Query.FieldByName('ID_PEDIDO').AsString);
                Pedido.AddPair('DESCRICAO_PRODUTO', Query2.FieldByName('DESCRICAO').AsString);
                Pedido.AddPair('SEQ_PED', Query.FieldByName('SEQ_PED').AsString);
                Pedido.AddPair('QUANTIDADE', Query.FieldByName('QUANTIDADE').AsString);
                Pedido.AddPair('PRECO_UNITARIO', Query2.FieldByName('PRECO').AsString);
                Pedidos.AddElement(Pedido);
              except
                Produto.Free;
                raise;
              end;
              Query.Next;
             end;
          Res.Send<TJSONArray>(Pedidos).Status(THTTPStatus.OK);
          finally
            Query.Free;
          end;
      end);


  THorse.Listen(9000);

  //finally
    //writeln('Erro ao conectar');
  //end;

end.

