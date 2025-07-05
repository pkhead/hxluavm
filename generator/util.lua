function table.find(t, q)
    for i, v in pairs(t) do
        if v == q then
            return i
        end
    end
    return nil
end