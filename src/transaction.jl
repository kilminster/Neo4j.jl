# Transactions
# A transaction is the primary type through which the database is accessed. A
# transaction can be a single request, or it can be held open through many
# requests as a means of batching jobs together.

export transaction, rollback, commit

struct Transaction
  conn::Connection
  commit::AbstractString
  location::AbstractString
  statements::Vector{Statement}
end

# TODO: Provide a version that accepts statements.
function transaction(conn::Connection)
    url = connurl(conn, "transaction")
    headers = connheaders(conn)
    body = Dict("statements" => [ ])
    
    resp = HTTP.post(url; headers=headers, json=body)
    if resp.status != 201
        error("Failed to connect to database ($(resp.status)): $(conn)\n$(resp)")
    end
    
    respdata = JSON.parse(String(resp.body))
    respheaders=Dict(resp.headers...)
    
    Transaction(conn, respdata["commit"], respheaders["Location"], Statement[])
end

function (txn::Transaction)(cypher::AbstractString, params::Pair...;
    submit::Bool=false)
  append!(txn.statements, [Statement(cypher, Dict(params))])
  if submit
    url = txn.location
    headers = connheaders(txn.conn)
    body = Dict("statements" => txn.statements)

    resp = HTTP.post(url; headers=headers, json=body)

    if resp.status != 200
      error("Failed to submit transaction ($(resp.status)): $(txn)\n$(resp)")
    end
#    respdata = Requests.json(resp)
      respdata=JSON.parse(String(resp.body))
      
    empty!(txn.statements)
    result = Result(respdata["results"], respdata["errors"])

    result
  end
end

function commit(txn::Transaction)
    url = txn.commit
    headers = connheaders(txn.conn)
    body = Dict("statements" => txn.statements)
    
    resp = HTTP.post(url; headers=headers, json=body)
    
    if resp.status != 200
        error("Failed to commit transaction ($(resp.status)): $(txn)\n$(resp)")
    end
#    respdata = Requests.json(resp)
    respdata=JSON.parse(String(resp.body))
    
    Result(respdata["results"], respdata["errors"])
end

function rollback(txn::Transaction)
  url = txn.location
  headers = connheaders(txn.conn)

    #  resp = Requests.delete(url; headers=headers)
    resp = HTTP.delete(url; headers=headers)
  if resp.status != 200
    error("Failed to rollback transaction ($(resp.status)): $(txn)\n$(resp)")
  end
end

