# for (gnu) version of netcat (in Ubuntu)

# server
while (true) ; do nc -vvv -l 0.0.0.0 5678 ; done

# also 
# while (true) ; do echo "conn" >> nc.txt ; nc -vvv -l 0.0.0.0 5678 >> nc.txt ; done
# 
# in other terminal:
# tail -f nc.txt (or 'less' with Shift+F to follow) 
# 
# if client crashes, server may still loop (and will not accept new connections)
#  in such a case, issue in other terminal: sudo killall nc 



# client
echo "blabla" | nc 192.168.1.1 5678

