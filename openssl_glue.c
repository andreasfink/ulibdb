//
//  openssl_glue.c
//  ulibdb
//
//  Created by Andreas Fink on 14.12.2023.
//  Copyright © 2023 Andreas Fink (andreas@fink.org). All rights reserved.
//


/* SSL_get0_peer_certificate() and SSL_get1_peer_certificate() were added in 3.0.0.
   SSL_get_peer_certificate() was deprecated in 3.0.0.
   so we need to simulate the old for the new
*/

extern void *SSL_get1_peer_certificate(void *ssl);

void *SSL_get_peer_certificate(void *ssl)
{
    return SSL_get1_peer_certificate(ssl);
}
